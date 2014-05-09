require 'omnibus'
require 'fauxhai'

module Omnibus
  module RSpec
    SPEC_DATA = File.expand_path(File.join(File.dirname(__FILE__), 'data'))

    def software_path(name)
      File.join(SPEC_DATA, 'software', "#{name}.rb")
    end

    def overrides_path(name)
      File.join(SPEC_DATA, 'overrides', "#{name}.overrides")
    end

    def project_path(name)
      File.join(SPEC_DATA, 'projects', "#{name}.rb")
    end

    def complicated_path
      File.join(SPEC_DATA, 'complicated')
    end

    def fixtures_path
      File.expand_path('../fixtures', __FILE__)
    end

    def tmp_path
      File.expand_path('../../tmp', __FILE__)
    end

    #
    # Stub the given environment key.
    #
    # @param [String] key
    # @param [String] value
    #
    def stub_env(key, value)
      ENV.stub(:[]).and_call_original
      ENV.stub(:[]).with(key).and_return(value.to_s)
    end

    #
    # Stub Ohai with the given data.
    #
    # @param [Hash] data
    #
    def stub_ohai(data = {})
      system = ::Ohai::System.new
      system.data = Mash.new(data)

      Ohai.stub(:ohai).and_return(system)
    end

    #
    # Grab the result of the log command. Since Omnibus uses the block form of
    # the logger, this method handles both types of logging.
    #
    # @example
    #   output = capture_logging { some_command }
    #   expect(output).to include('whatever')
    #
    def capture_logging
      Omnibus.log.level = :debug
      original = $stdout
      $stdout = fake = StringIO.new

      [:fatal, :error, :warn, :info, :debug].each do |level|
        Omnibus.log.stub(level) do |args, &b|
          if b
            fake.puts(b.call)
          else
            fake.puts(args.join)
          end
        end
      end

      yield

      fake.string
    ensure
      Omnibus.log_level = :unknown
      $stdout = original
    end
  end
end

def windows?
  !!(RUBY_PLATFORM =~ /mswin|mingw|windows/)
end

def mac?
  !!(RUBY_PLATFORM =~ /darwin/)
end

RSpec.configure do |config|
  config.include Omnibus::RSpec
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
  config.treat_symbols_as_metadata_keys_with_true_values = true

  config.filter_run_excluding windows_only: true unless windows?
  config.filter_run_excluding mac_only: true unless mac?

  config.before(:each) do
    # Suppress logging
    Omnibus.log_level = :unknown

    # Clear the tmp_path on each run
    FileUtils.rm_rf(tmp_path)
    FileUtils.mkdir_p(tmp_path)
  end

  # Force the expect syntax
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Run specs in a random order
  config.order = 'random'
end
