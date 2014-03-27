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

    def fixtures_path
      File.expand_path('../fixtures', __FILE__)
    end

    def tmp_path
      File.expand_path('../../tmp', __FILE__)
    end
  end
end

RSpec.configure do |config|
  config.include Omnibus::RSpec
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
  config.treat_symbols_as_metadata_keys_with_true_values = true

  # Clear the tmp_path on each run
  config.before(:each) do
    FileUtils.rm_rf(tmp_path)
    FileUtils.mkdir_p(tmp_path)
  end

  # Force the expect syntax
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
