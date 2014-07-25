require 'rspec'
require 'rspec/its'

require 'omnibus'

def windows?
  !!(RUBY_PLATFORM =~ /mswin|mingw|windows/)
end

def mac?
  !!(RUBY_PLATFORM =~ /darwin/)
end

RSpec.configure do |config|
  # Custom matchers and shared examples
  require_relative 'support/examples'
  require_relative 'support/matchers'

  require_relative 'support/env_helpers'
  config.include(Omnibus::RSpec::EnvHelpers)

  require_relative 'support/file_helpers'
  config.include(Omnibus::RSpec::FileHelpers)

  require_relative 'support/git_helpers'
  config.include(Omnibus::RSpec::GitHelpers)

  require_relative 'support/logging_helpers'
  config.include(Omnibus::RSpec::LoggingHelpers)

  require_relative 'support/ohai_helpers'
  config.include(Omnibus::RSpec::OhaiHelpers)

  require_relative 'support/path_helpers'
  config.include(Omnibus::RSpec::PathHelpers)

  config.filter_run(focus: true)
  config.run_all_when_everything_filtered = true

  config.filter_run_excluding(windows_only: true) unless windows?
  config.filter_run_excluding(mac_only: true) unless mac?

  config.before(:each) do
    # Suppress logging
    Omnibus.logger.level = :unknown

    # Reset config
    Omnibus.reset!

    # Clear the tmp_path on each run
    FileUtils.rm_rf(tmp_path)
    FileUtils.mkdir_p(tmp_path)

    # Don't run Ohai - tests can still override this
    stub_ohai(platform: 'ubuntu', version: '12.04')
  end

  config.after(:each) do
    Omnibus.reset!
  end

  # Force the expect syntax
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Run specs in a random order
  config.order = 'random'
end

#
# Shard example group for asserting a DSL method
#
# @example
#   it_behaves_like 'a cleanroom setter', :name, <<-EOH
#     name 'foo'
#   EOH
#
RSpec.shared_examples 'a cleanroom setter' do |id, string|
  it "for `#{id}'" do
    expect { subject.evaluate(string) }
      .to_not raise_error
  end
end

#
# Shard example group for asserting a DSL method
#
# @example
#   it_behaves_like 'a cleanroom getter', :name
#
RSpec.shared_examples 'a cleanroom getter' do |id|
  it "for `#{id}'" do
    expect { subject.evaluate("#{id}") }.to_not raise_error
  end
end
