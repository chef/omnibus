require 'rspec'
require 'rspec/its'

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
      unless @__env_already_stubbed__
        ENV.stub(:[]).and_call_original
        @__env_already_stubbed__ = true
      end

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
      original = Omnibus.logger
      Omnibus.logger = TestLogger.new
      yield
      Omnibus.logger.output
    ensure
      Omnibus.logger = original
    end
  end
end

module Omnibus
  class TestLogger < Logger
    def initialize(*)
      super(StringIO.new)
      @level = -1
    end

    def output
      @logdev.dev.string
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
    Omnibus.logger.level = :unknown

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
