require "rspec"
require "rspec/its"
require "rspec/json_expectations"
require "webmock/rspec"

require "cleanroom/rspec"

require "omnibus"

def windows?
  !!(RUBY_PLATFORM =~ /mswin|mingw|windows/)
end

def mac?
  !!(RUBY_PLATFORM =~ /darwin/)
end

RSpec.configure do |config|
  # Custom matchers and shared examples
  require_relative "support/examples"
  require_relative "support/matchers"

  require_relative "support/env_helpers"
  config.include(Omnibus::RSpec::EnvHelpers)

  require_relative "support/file_helpers"
  config.include(Omnibus::RSpec::FileHelpers)

  require_relative "support/git_helpers"
  config.include(Omnibus::RSpec::GitHelpers)

  require_relative "support/logging_helpers"
  config.include(Omnibus::RSpec::LoggingHelpers)

  require_relative "support/ohai_helpers"
  config.include(Omnibus::RSpec::OhaiHelpers)

  require_relative "support/output_helpers"
  config.include(Omnibus::RSpec::OutputHelpers)

  require_relative "support/path_helpers"
  config.include(Omnibus::RSpec::PathHelpers)

  require_relative "support/shell_helpers"
  config.include(Omnibus::RSpec::ShellHelpers)

  config.filter_run(focus: true)
  config.run_all_when_everything_filtered = true

  config.filter_run_excluding(windows_only: true) unless windows?
  config.filter_run_excluding(mac_only: true) unless mac?
  config.filter_run_excluding(not_supported_on_windows: true) if windows?

  if config.files_to_run.one?
    # Use the documentation formatter for detailed output,
    # unless a formatter has already been configured
    # (e.g. via a command-line flag).
    config.default_formatter = "doc"
    config.color = true
  end

  config.before(:each) do
    # Suppress logging
    Omnibus.logger.level = :nothing

    # Reset config
    Omnibus.reset!
    Omnibus::Config.append_timestamp(false)

    # Clear the tmp_path on each run
    FileUtils.rm_rf(tmp_path)
    FileUtils.mkdir_p(tmp_path)

    # Don't run Ohai - tests can still override this
    stub_ohai(platform: "ubuntu", version: "12.04")

    # Default to real HTTP requests
    WebMock.allow_net_connect!
  end

  config.after(:each) do
    Omnibus.reset!
  end

  # Force the expect syntax
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Run specs in a random order
  config.order = "random"
end

#
# Shard example group for asserting a DSL method
#
# @example
#   it_behaves_like 'a cleanroom setter', :name, <<-EOH
#     name 'foo'
#   EOH
#
RSpec.shared_examples "a cleanroom setter" do |id, string|
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
RSpec.shared_examples "a cleanroom getter" do |id|
  it "for `#{id}'" do
    expect { subject.evaluate("#{id}") }.to_not raise_error
  end
end
