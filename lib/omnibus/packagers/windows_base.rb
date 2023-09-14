#
# Copyright 2016-2018 Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module Omnibus
  class Packager::WindowsBase < Packager::Base
    DEFAULT_TIMESTAMP_SERVERS = ["http://timestamp.digicert.com",
                                 "http://timestamp.verisign.com/scripts/timestamp.dll"].freeze

    #
    # Set the signing certificate name
    #
    # @example
    #   signing_identity 'FooCert'
    #   signing_identity 'FooCert', store: 'BarStore'
    #
    # @param [String] thumbprint
    #   the thumbprint of the certificate in the certificate store
    # @param [Hash<Symbol, String>] params
    #   an optional hash that defines the parameters for the singing identity
    #
    # @option params [String] :store (My)
    #   The name of the certificate store which contains the certificate
    # @option params [Array<String>, String] :timestamp_servers
    #   A trusted timestamp server or a list of truested timestamp servers to
    #   be tried. They are tried in the order provided.
    # @option params [TrueClass, FalseClass] :machine_store (false)
    #   If set to true, the local machine store will be searched for a valid
    #   certificate. Otherwise, the current user store is used
    #
    #   Setting nothing will default to trying ['http://timestamp.digicert.com',
    #   'http://timestamp.verisign.com/scripts/timestamp.dll']
    #
    # @return [Hash{:thumbprint => String, :store => String, :timestamp_servers => Array[String]}]
    #
    def signing_identity(thumbprint = NULL, params = NULL)
      unless null?(thumbprint)
        @signing_identity = {}
        unless thumbprint.is_a?(String)
          raise InvalidValue.new(:signing_identity, "be a String")
        end

        @signing_identity[:thumbprint] = thumbprint

        if !null?(params)
          unless params.is_a?(Hash)
            raise InvalidValue.new(:params, "be a Hash")
          end

          valid_keys = %i{store timestamp_servers machine_store algorithm keypair_alias}
          invalid_keys = params.keys - valid_keys
          unless invalid_keys.empty?
            raise InvalidValue.new(:params, "contain keys from [#{valid_keys.join(", ")}]. "\
                                   "Found invalid keys [#{invalid_keys.join(", ")}]")
          end

          if !params[:machine_store].nil? && !(
             params[:machine_store].is_a?(TrueClass) ||
             params[:machine_store].is_a?(FalseClass))
            raise InvalidValue.new(:params, "contain key :machine_store of type TrueClass or FalseClass")
          end
        else
          params = {}
        end

        @signing_identity[:store] = params[:store] || "My"
        @signing_identity[:algorithm] = params[:algorithm] || "SHA256"
        # TODO: Remove dependency on timestamp_servers when is_signed? is in working condition
        servers = params[:timestamp_servers] || DEFAULT_TIMESTAMP_SERVERS
        @signing_identity[:timestamp_servers] = [servers].flatten
        @signing_identity[:machine_store] = params[:machine_store] || false
        @signing_identity[:keypair_alias] = params[:keypair_alias]
      end

      @signing_identity
    end
    expose :signing_identity

    def thumbprint
      signing_identity[:thumbprint]
    end

    def algorithm
      signing_identity[:algorithm]
    end

    def cert_store_name
      signing_identity[:store]
    end

    def timestamp_servers
      signing_identity[:timestamp_servers]
    end

    def keypair_alias
      signing_identity[:keypair_alias]
    end

    def machine_store?
      signing_identity[:machine_store]
    end

    # signs the package with the given certificate
    def sign_package(package_file)
      raise FailedToSignWindowsPackage.new unless is_signed?(package_file)
    end

    def is_signed?(package_file)
      cmd = [].tap do |arr|
        arr << "smctl.exe"
        arr << "sign"
        arr << "--fingerprint #{thumbprint}"
        arr << "--input #{package_file}"
      end.join(" ")

      status = shellout(cmd)

      # TODO: Once things are working, remove this block
      puts "---- These are some temporary debug statements ----"
      puts "package_file: #{package_file}"
      puts "cmd: #{cmd}"
      puts "status: #{status}"
      puts "status.exitstatus: #{status.exitstatus}"
      puts "status.stdout: #{status.stdout}"
      puts "status.stderr: #{status.stderr}"
      puts "---- end of temporary debug statements -----"

      # log the error if the signing failed
      if status.exitstatus != 0
        log.warn(log_key) do
          <<-EOH.strip
                Failed to verify signature of #{package_file}

                STDOUT
                ------
                #{status.stdout}

                STDERR
                ------
                #{status.stderr}
          EOH
        end
      end

      status.exitstatus == 0
    end

    # TODO: Remove this method once is_signed? is in working condition
    def try_sign(package_file, url)
      cmd = [].tap do |arr|
        arr << "signtool.exe"
        arr << "sign /v"
        arr << "/t #{url}"
        arr << "/fd #{algorithm}"
        arr << "/sm" if machine_store?
        arr << "/s #{cert_store_name}"
        arr << "/sha1 #{thumbprint}"
        arr << "/d #{project.package_name}"
        arr << "\"#{package_file}\""
      end.join(" ")
      status = shellout(cmd)
      if status.exitstatus != 0
        log.warn(log_key) do
          <<-EOH.strip
                Failed to add timestamp with timeserver #{url}

                STDOUT
                ------
                #{status.stdout}

                STDERR
                ------
                #{status.stderr}
          EOH
        end
      end
      status.exitstatus == 0
    end

    #
    # Get the certificate subject of the signing identity
    #
    # @return [String]
    #
    def certificate_subject
      return "CN=#{project.package_name}" unless signing_identity

      store = machine_store? ? "LocalMachine" : "CurrentUser"
      cmd = [].tap do |arr|
        arr << "powershell.exe"
        arr << "-ExecutionPolicy Bypass"
        arr << "-NoProfile"
        arr << "-Command (Get-Item Cert:/#{store}/#{cert_store_name}/#{thumbprint}).Subject"
      end.join(" ")

      shellout!(cmd).stdout.strip
    end

    #
    # Parse and return the version from the {Project#build_version}.
    #
    # A project's +build_version+ looks something like:
    #
    #     dev builds => 11.14.0-alpha.1+20140501194641.git.94.561b564
    #                => 0.0.0+20140506165802.1
    #
    #     rel builds => 11.14.0.alpha.1 || 11.14.0
    #
    # The appx and msi version specs expects a version that looks like X.Y.Z.W where
    # X, Y, Z & W are all 32 bit integers.
    #
    # @return [String]
    #
    def windows_package_version
      major, minor, patch = project.build_version.split(/[.+-]/)
      [major, minor, patch, project.build_iteration].join(".")
    end
  end
end
