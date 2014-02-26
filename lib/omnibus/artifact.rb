module Omnibus
  class Artifact
    attr_reader :path
    attr_reader :platforms
    attr_reader :config

    # @param path [String] relative or absolute path to a package file.
    # @param platforms [Array<Array<String, String, String>>] an Array of
    #   distro, distro version, architecture tuples. By convention, the first
    #   platform is the platform on which the artifact was built.
    # @param config [#Hash<Symbol, Object>] configuration for the release.
    #   Artifact only uses `:build_version => String`.
    def initialize(path, platforms, config)
      @path = path
      @platforms = platforms
      @config = config
    end

    # Adds this artifact to the `release_manifest`, which is mutated. Intended
    # to be used in a visitor-pattern fashion over a collection of Artifacts to
    # generate a final release manifest.
    #
    # @param release_manifest [Hash{ String => Hash }] a version 1 style release
    #   manifest Hash (see example)
    #
    # @example Add the package to release_manifest:
    #   add_to_release_manifest!( {} )
    #     "el" => {
    #       "5" => { "x86_64" => { "11.4.0-1" => "/el/5/x86_64/demoproject-11.4.0-1.el5.x86_64.rpm" } }
    #     }
    # @return [Hash{String=>Hash}] the updated release manifest.
    def add_to_release_manifest!(release_manifest)
      platforms.each do |distro, version, arch|
        release_manifest[distro] ||= {}
        release_manifest[distro][version] ||= {}
        release_manifest[distro][version][arch] = { build_version => relpath }
        # TODO: when adding checksums, the desired format is like this:
        # build_support_json[platform][platform_version][machine_architecture][options[:version]]["relpath"] = build_location
      end
      release_manifest
    end

    # Adds this artifact to the `release_manifest`, which is mutated. Intended
    # to be used in a visitor-pattern fashion over a collection of Artifacts to
    # generate a final release manifest.
    #
    # @param release_manifest [Hash{ String => Hash }] a version 2 style release
    #   manifest Hash (see example)
    #
    # @example Add the package to release_manifest:
    #   add_to_release_manifest!( {} )
    #     "el" => {
    #       "5" => {
    #         "x86_64" => {
    #           "11.4.0-1" => {
    #             "relpath" => "/el/5/x86_64/demoproject-11.4.0-1.el5.x86_64.rpm",
    #             "md5" => "123f00d...",
    #             "sha256" => 456beef..."
    #           }
    #         }
    #       }
    #     }
    # @return [Hash{String=>Hash}] the updated release manifest.
    def add_to_v2_release_manifest!(release_manifest)
      platforms.each do |distro, version, arch|
        pkg_info = {
          'relpath' => relpath,
          'md5'     => md5,
          'sha256'  => sha256,
        }

        release_manifest[distro] ||= {}
        release_manifest[distro][version] ||= {}
        release_manifest[distro][version][arch] = { build_version => pkg_info  }
      end
      release_manifest
    end

    # Metadata about the artifact as a flat Hash.
    #
    # @example For a RHEL/CentOS 6, 64-bit package of project version 11.4.0-1
    #   flat_metadata
    #     { "platform" => "el",
    #       "platform_version" => "6",
    #       "arch" => "x86_64",
    #       "version" => "11.4.0-1",
    #       "md5" => "d41d8cd98f00b204e9800998ecf8427e",
    #       "sha256" => "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" }
    #
    # @return [Hash{String=>String}] the artifact metadata
    def flat_metadata
      distro, version, arch = build_platform
      {
        'platform' => distro,
        'platform_version' => version,
        'arch' => arch,
        'version' => build_version,
        'basename' => File.basename(path),
        'md5' => md5,
        'sha256' => sha256,
      }
    end

    # Platform on which the artifact was built. By convention, this is the
    # first in the list of platforms passed to {#initialize}.
    # @return [Array<String, String, String>] an Array of distro, distro
    #   version, architecture.
    def build_platform
      platforms.first
    end

    # @return [String] build version of the project.
    def build_version
      config[:version]
    end

    # @return [String] relative path at which the artifact should be located
    #   when uploaded to artifact repo.
    # @example Chef 11.4.0-1 on 64 bit RHEL 6:
    #   relpath
    #     "/el/6/x86_64/chef-11.4.0-1.el5.x86_64.rpm"
    def relpath
      # upload build to build platform directory
      "/#{build_platform.join('/')}/#{path.split('/').last}"
    end

    # @return [String] hex encoded MD5 of the package
    def md5
      @md5 ||= digest(Digest::MD5)
    end

    # @return [String] hex encoded SHA2-256 of the package
    def sha256
      @sha256 ||= digest(Digest::SHA256)
    end

    private

    def digest(digest_class)
      digest = digest_class.new
      File.open(path) do |io|
        while (chunk = io.read(1024 * 8))
          digest.update(chunk)
        end
      end
      digest.hexdigest
    end
  end
end
