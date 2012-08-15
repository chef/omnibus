maintainer        "Opscode, Inc."
maintainer_email  "cookbooks@opscode.com"
license           "Apache 2.0"
description       "Omnibus base O/S configuration"
long_description  IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version           "0.10.0"

%w{ ubuntu debian arch centos solaris2 }.each do |os|
  supports os
end

%w{ opencsw git build-essential solaris_omgwtfbbq }.each do |cb|
  depends cb
end
