require "aruba"
require "aruba/cucumber"
require "aruba/in_process"

require "omnibus/cli"

Aruba.configure do |config|
  config.command_launcher = :in_process
  config.main_class = Omnibus::CLI::Runner
end

Before do
  # Reset anything that might have been cached in the Omnibus project
  Omnibus.reset!(true)
end
