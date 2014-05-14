require 'aruba'
require 'aruba/cucumber'
require 'aruba/in_process'

require 'omnibus/cli'

Before do
  # Reset anything that might have been cached in the Omnibus project
  Omnibus.reset!(true)

  Aruba::InProcess.main_class = Omnibus::CLI::Runner
  Aruba.process = Aruba::InProcess
end
