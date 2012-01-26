$:.unshift File.expand_path("../lib", __FILE__)

require 'omnibus'

FileList['config/software/*.rb'].each do |f|
  Omnibus::Software.new(IO.read(f))
end
