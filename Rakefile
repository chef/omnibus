$:.unshift File.expand_path("../lib", __FILE__)

require 'omnibus'

Omnibus.software("config/software/*.rb")

desc "Print the name and version of all components"
task :versions do
  puts Omnibus::Reports.pretty_version_map
end

