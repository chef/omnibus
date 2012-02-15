#!/usr/bin/env ruby

bad_libs = {}
whitelist_libs = [
  /linux-vdso.+/,
  /libc\.so/,
  /ld-linux/,
  /libdl/,
  /libpthread/,
  /libm\.so/,
  /libcrypt\.so/,
  /librt\.so/,
  /libutil\.so/,
  /libgcc_s\.so/,
  /libstdc\+\+\.so/,
  /libnsl\.so/,
  /libfreebl\d\.so/,
  /libresolv\.so/
]

# TODO: use ldd on all regular filles and ignore those that aren't dynamically executable
# ldd_output = `find /opt/opscode -type f | xargs ldd`

ldd_output = `find /opt/opscode -name '*.so' -o -name '*.cgi' -o -path '/opt/opscode/embedded/nagios/libexec/*' | xargs ldd`

current_library = nil 
ldd_output.split("\n").each do |line|
  case line
  when /^(.+):$/
    current_library = $1
  when /^\s+(.+) \=\> (.+) \(.+\)$/
    name = $1
    linked = $2
    safe = nil
    whitelist_libs.each do |reg| 
      safe ||= true if reg.match(name)
    end
    safe ||= true if current_library =~ /jre\/lib/

    if !safe && linked !~ /\/opt\/opscode/
      bad_libs[current_library] ||= {}
      bad_libs[current_library][name] ||= {} 
      if bad_libs[current_library][name].has_key?(linked)
        bad_libs[current_library][name][linked] += 1 
      else
        bad_libs[current_library][name][linked] = 1 
      end
    else
      puts "Passed: #{current_library} #{name} #{linked}" if ARGV[0] == 'verbose'
    end
  when /^\s+(.+) \(.+\)$/
    next
  when /^\s+statically linked$/
    next
  when /^\s+libjvm.so/
    next
  when /^\s+libjava.so/
    next
  when /^\s+libmawt.so/
    next
  when /^\s+not a dynamic executable$/
  else
    puts "line did not match for #{current_library}\n#{line}"
  end
end

if bad_libs.keys.length > 0
  bad_libs.each do |name, lib_hash|
    lib_hash.each do |lib, linked_libs|
      linked_libs.each do |linked, count|
        puts "#{name}: #{lib} #{linked} #{count}"
      end
    end
  end
  exit 1
else
  exit 0
end
