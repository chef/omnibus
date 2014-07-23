#!/usr/bin/env ruby

require 'rubygems'
require 'systemu'
require 'net/ssh/multi'

BASE_PATH = File.dirname(__FILE__)
VM_BASE_PATH = File.expand_path("~/Documents/Virtual Machines.localized")
PROJECT = ARGV[0]
BUCKET = ARGV[1]
S3_ACCESS_KEY = ARGV[2]
S3_SECRET_KEY = ARGV[3]
SPECIFIC_HOSTS = ARGV[4..-1] || []

Dir.mkdir "#{BASE_PATH}/build-output" unless File.directory?("#{BASE_PATH}/build-output")

hosts_to_build = {
  'debian-6-i686' => "debian-6-i386.opscode.us",
  'debian-6-x86_64' => "debian-6-x86-64.opscode.us",
  'el-6-i686' => "centos-62-i386.opscode.us",
  'el-6-x86_64' => "centos-62-x86-64.opscode.us",
  'el-5.6-i686' => "centos-5-i386.opscode.us", 
  'el-5.6-x86_64' => "centos-5-x86-64.opscode.us",
  'ubuntu-1004-i686' => "ubuntu-1004-i386.opscode.us",
  'ubuntu-1004-x86_64' => "ubuntu-1004-x86-64.opscode.us",
  'ubuntu-1104-i686' => "ubuntu-1104-i386.opscode.us",
  'ubuntu-1104-x86_64' => "ubuntu-1104-x86-64.opscode.us",
  'openindiana-148-i686' => "openindiana-148-i386.opscode.us"
}
build_to_hosts = hosts_to_build.invert 
build_status = {}

def run_command(cmd)
  status, stdout, stderr = systemu cmd 
  raise "Command failed: #{stdout}, #{stderr}" if status.exitstatus != 0
end

session = Net::SSH::Multi.start(:concurrent_connections => 6)
hosts_to_build.each do |host_type, build_host|
  if SPECIFIC_HOSTS.length > 0
    next unless SPECIFIC_HOSTS.include?(host_type)
  end
  session.use("root@#{build_host}")
end
channel = session.exec "/root/omnibus/build-omnibus.sh #{PROJECT} #{BUCKET} '#{S3_ACCESS_KEY}' '#{S3_SECRET_KEY}'" do |ch, stream, data|
  puts "[#{build_to_hosts[ch[:host]]}] #{data}"
end
session.loop
channel.each do |c|
  build_status[build_to_hosts[c[:host]]] = c[:exit_status] == 0 ? "success" : "failed"
  output_file = "#{BASE_PATH}/build-output/#{build_to_hosts[c[:host]]}.out"
  run_command "scp root@#{c[:host]}:/tmp/omnibus.out '#{output_file}'"
  puts "[#{c[:host]}] Build output captured to #{output_file}"
end
session.close

puts "------------"
exit_code = 0  
build_status.keys.sort.each do |key|
  if build_status[key] == 'failed'
    exit_code = 1 
  end
  puts "#{key}: #{build_status[key]}"
end

exit exit_code

