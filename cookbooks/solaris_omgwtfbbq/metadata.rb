maintainer        "Opscode, Inc."
maintainer_email  "cookbooks@opscode.com"
license           "Apache 2.0"
description       "Make solaris produce less rageface"
long_description  IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version           "0.10.0"

%w{ solaris2 }.each do |os|
  supports os
end

%w{ opencsw }.each do |cb|
  depends cb
end
