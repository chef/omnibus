require 'forwardable'

module Omnibus
  class Builder

    # Proxies method calls to either a Builder object or the Software that the
    # builder belongs to. Provides compatibility with our DSL where we never
    # yield objects to blocks and hopefully hides some of the confusion that
    # can arise from instance_eval.
    class DSLProxy
      extend Forwardable

      def_delegator :@builder, :command
      def_delegator :@builder, :name


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

    #--
    # TODO: code duplication with Fetcher::ErrorReporter
    class ErrorReporter

      def initialize(error, fetcher)
        @error, @fetcher = error, fetcher
      end

      def e
        @error
      end

      def explain(why)
        $stderr.puts "* " * 40
        $stderr.puts why
        $stderr.puts "Exception:"
        $stderr.puts indent("#{e.class}: #{e.message.strip}", 2)
        Array(e.backtrace).each {|l| $stderr.puts indent(l, 4) }
        $stderr.puts "* " * 40
      end

      private

      def indent(string, n)
        string.split("\n").map {|l| " ".rjust(n) << l }.join("\n")
      end

    end

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

    def project_dir
      @software.project_dir
    end

    def log(message)
      puts "[builder:#{name}] #{message}"
    end

    def build
      log "building #{name}"
      @build_commands.each do |cmd|
        execute(cmd)
      end
    end

    def execute(cmd)
      shell = nil
      cmd_args = Array(cmd)
      options = {
        :cwd => project_dir,
        :timeout => 3600
      }
      options[:live_stream] = STDOUT if ENV['DEBUG']
      if cmd_args.last.is_a? Hash
        cmd_options = cmd_args.last
        cmd_args[cmd_args.size - 1] = options.merge(cmd_options)
      else
        cmd_args << options
      end

      cmd_string = cmd_args[0..-2].join(' ')
      cmd_opts_for_display = cmd_args.last.inject([]) {|opts, (k,v)| opts << "#{k}='#{v}'"}.join(",")

      log "Executing: `#{cmd_string}` with #{cmd_opts_for_display}"

      shell = Mixlib::ShellOut.new(*cmd)
      shell.run_command
      shell.error!
    rescue Exception => e
      ErrorReporter.new(e, self).explain("Failed to build #{name} while running `#{cmd_string}` with #{cmd_opts_for_display}")
      raise
    end

  end

  class NullBuilder < Builder

    def build
      log "Nothing to build for #{name}"
    end

  end

end
