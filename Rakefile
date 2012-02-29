$:.unshift File.expand_path("../lib", __FILE__)

require 'omnibus'

Omnibus.software("config/software/*.rb")

Omnibus::CleanTasks.define!

desc "Print the name and version of all components"
task :versions do
  puts Omnibus::Reports.pretty_version_map
end

desc "Run the health check against #{Omnibus.config.install_dir}"
task :health_check do
  Omnibus::HealthCheck.run
end
