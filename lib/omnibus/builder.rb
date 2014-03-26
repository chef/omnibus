#
# Copyright:: Copyright (c) 2012-2014 Chef Software, Inc.
# License:: Apache License, Version 2.0
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

require 'forwardable'
require 'omnibus/exceptions'
require 'omnibus/install_path_cache'
require 'ostruct'

module Omnibus
  class Builder
    # Proxies method calls to either a Builder object or the Software that the
    # builder belongs to. Provides compatibility with our DSL where we never
    # yield objects to blocks and hopefully hides some of the confusion that
    # can arise from instance_eval.
    class DSLProxy
      extend Forwardable

      def_delegator :@builder, :patch
      def_delegator :@builder, :erb
      def_delegator :@builder, :command
      def_delegator :@builder, :ruby
      def_delegator :@builder, :gem
      def_delegator :@builder, :bundle
      def_delegator :@builder, :rake
      def_delegator :@builder, :block
      def_delegator :@builder, :name
      def_delegator :@builder, :project_root

      def initialize(builder, software)
        @builder, @software = builder, software
      end

      def eval_block(&block)
        instance_eval(&block)
      end

      def respond_to?(method)
        super || @software.respond_to?(method)
      end

      def methods
        super | @software.methods
      end

      def method_missing(method_name, *args, &block)
        if @software.respond_to?(method_name)
          @software.send(method_name, *args, &block)
        else
          super
        end
      end
    end

    # @todo code duplication with {Fetcher::ErrorReporter}
    class ErrorReporter
      # @todo fetcher isn't even used
      def initialize(error, fetcher)
        @error, @fetcher = error, fetcher
      end

      # @todo this isn't necessary
      def e
        @error
      end

      def explain(why)
        $stderr.puts '* ' * 40
        $stderr.puts why
        $stderr.puts 'Exception:'
        $stderr.puts indent("#{e.class}: #{e.message.strip}", 2)
        Array(e.backtrace).each { |l| $stderr.puts indent(l, 4) }
        $stderr.puts '* ' * 40
      end

      private

      def indent(string, n)
        string.split("\n").map { |l| ' '.rjust(n) << l }.join("\n")
      end
    end

    # @todo Look at using Bundler.with_clean_env{ ... } instead
    BUNDLER_BUSTER = {
      'RUBYOPT'         => nil,
      'BUNDLE_BIN_PATH' => nil,
      'BUNDLE_GEMFILE'  => nil,
      'GEM_PATH'        => nil,
      'GEM_HOME'        => nil,
    }

    attr_reader :build_commands

    def initialize(software, &block)
      @software = software
      @build_commands = []
      @dsl_proxy = DSLProxy.new(self, software)
      @dsl_proxy.eval_block(&block) if block_given?
    end

    def name
      @software.name
    end

    def command(*args)
      @build_commands << args
    end

    def patch(*args)
      args = args.dup.pop

      # we'll search for a patch file in the project root AND
      # the omnibus-software gem
      candidate_roots = [Omnibus.project_root]
      candidate_roots << Omnibus.omnibus_software_root if Omnibus.omnibus_software_root

      candidate_paths = candidate_roots.map do |root|
        File.expand_path("#{root}/config/patches/#{name}/#{args[:source]}")
      end

      source = candidate_paths.find { |path| File.exist?(path) }

      unless source
        fail MissingPatch.new(args[:source], candidate_paths)
      end

      plevel = args[:plevel] || 1
      if args[:target]
        target = File.expand_path("#{project_dir}/#{args[:target]}")
        @build_commands <<
         "cat #{source} | patch -p#{plevel} #{target}"
      else
        @build_commands <<
         "patch -d #{project_dir} -p#{plevel} -i #{source}"
      end
    end

    def erb(*args)
      args = args.dup.pop

      source_path = File.expand_path("#{Omnibus.project_root}/config/templates/#{name}/#{args[:source]}")

      unless File.exist?(source_path)
        fail MissingTemplate.new(args[:source], "#{Omnibus.project_root}/config/templates/#{name}")
      end

      block do
        template = ERB.new(File.new(source_path).read, nil, '%')
        File.open(args[:dest], 'w') do |file|
          file.write(template.result(OpenStruct.new(args[:vars]).instance_eval { binding }))
        end

        File.chmod(args[:mode], args[:dest])
      end
    end

    # @todo all these ruby commands (ruby, gem, bundle, rake) could
    #   all be collapsed into a single underlying implementation, since
    #   they all just differ on the executable being called
    def ruby(*args)
      @build_commands << bundle_bust(*prepend_cmd("#{install_dir}/embedded/bin/ruby", *args))
    end

    def gem(*args)
      @build_commands << bundle_bust(*prepend_cmd("#{install_dir}/embedded/bin/gem", *args))
    end

    def bundle(*args)
      @build_commands << bundle_bust(*prepend_cmd("#{install_dir}/embedded/bin/bundle", *args))
    end

    def rake(*args)
      @build_commands << bundle_bust(*prepend_cmd("#{install_dir}/embedded/bin/rake", *args))
    end

    def block(&rb_block)
      @build_commands << rb_block
    end

    def project_root
      Omnibus.project_root
    end

    def project_dir
      @software.project_dir
    end

    def install_dir
      @software.install_dir
    end

    def log(message)
      puts "[builder:#{name}] #{message}"
    end

    def build
      log "building #{name}"
      log "version overridden from #{@software.default_version} to " \
          "#{@software.version}" if @software.overridden?
      time_it("#{name} build") do
        @build_commands.each do |cmd|
          execute(cmd)
        end
      end
    end

    def execute(cmd)
      case cmd
      when Proc
        execute_proc(cmd)
      else
        execute_sh(cmd)
      end
    end

    private

    def execute_proc(cmd)
      cmd.call
    rescue Exception => e
      # In Ruby 1.9, Procs have a #source_location method with file/line info.
      # Too bad we can't use it :(
      ErrorReporter.new(e, self).explain("Failed to build #{name} while running ruby block build step")
      raise
    end

    def build_retries
      Omnibus.config[:build_retries]
    end

    def execute_sh(cmd)
      retries ||= 0
      shell = nil
      cmd_args = Array(cmd)
      options = {
        cwd: project_dir,
        timeout: 5400,
      }
      options[:live_stream] = STDOUT if ENV['DEBUG']
      if cmd_args.last.is_a? Hash
        cmd_options = cmd_args.last
        cmd_args[cmd_args.size - 1] = options.merge(cmd_options)
      else
        cmd_args << options
      end

      cmd_string = cmd_args[0..-2].join(' ')
      cmd_opts_for_display = to_kv_str(cmd_args.last)

      log "Executing: `#{cmd_string}` with #{cmd_opts_for_display}"

      shell = Mixlib::ShellOut.new(*cmd)
      shell.environment['HOME'] = '/tmp' unless ENV['HOME']

      cmd_name = cmd_string.split(/\s+/).first
      time_it("#{cmd_name} command") do
        shell.run_command
        shell.error!
      end
    rescue Exception => e
      raise if build_retries.nil? || build_retries == 0
      # Getting lots of errors from github, particularly with erlang/rebar
      # projects fetching tons of deps via git all the time. This isn't a
      # particularly elegant way to solve that problem. But it should work.
      if retries >= build_retries
        ErrorReporter.new(e, self).explain("Failed to build #{name} while running `#{cmd_string}` with #{cmd_opts_for_display}")
        raise
      else
        time_to_sleep = 5 * (2**retries)
        retries += 1
        log "Failed to execute cmd #{cmd} #{retries} time(s). Retrying in #{time_to_sleep}s."
        sleep(time_to_sleep)
        retry
      end
    end

    def prepend_cmd(str, *cmd_args)
      if cmd_args.size == 1
        # command as a string, no opts
        "#{str} #{cmd_args.first}"
      elsif cmd_args.size == 2 && cmd_args.last.is_a?(Hash)
        # command as a string w/ opts
        ["#{str} #{cmd_args.first}", cmd_args.last]
      elsif cmd_args.size == 0
        fail ArgumentError, "I don't even"
      else
        # cmd given as argv array
        cmd_args.dup.unshift(str)
      end
    end

    def bundle_bust(*cmd_args)
      if cmd_args.last.is_a?(Hash)
        cmd_args = cmd_args.dup
        cmd_opts = cmd_args.pop.dup
        cmd_opts[:env] = cmd_opts[:env] ? BUNDLER_BUSTER.merge(cmd_opts[:env]) : BUNDLER_BUSTER
        cmd_args << cmd_opts
      else
        cmd_args << { env: BUNDLER_BUSTER }
      end
    end

    def time_it(what)
      start = Time.now
      yield
    rescue Exception
      elapsed = Time.now - start
      log "#{what} failed, #{elapsed.to_f}s"
      raise
    else
      elapsed = Time.now - start
      log "#{what} succeeded, #{elapsed.to_f}s"
    end

    # Convert a hash to a string in the form `key=value`. It should work with
    # whatever input is given but is designed to make the options to ShellOut
    # look nice.
    def to_kv_str(hash, join_str = ',')
      hash.reduce([]) do |kv_pair_strs, (k, v)|
        val_str = case v
                  when Hash
                    %Q("#{to_kv_str(v, " ") }")
                  else
                    v.to_s
                  end
        kv_pair_strs << "#{k}=#{val_str}"
      end.join(join_str)
    end
  end

  class NullBuilder < Builder
    def build
      log "Nothing to build for #{name}"
    end
  end
end
