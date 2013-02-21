maintainer        "Opscode, Inc."
maintainer_email  "cookbooks@opscode.com"
license           "Apache 2.0"
description       "Omnibus base O/S configuration"
long_description  IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version           "0.10.0"

%w{ ubuntu debian arch centos solaris2 }.each do |os|
  supports os
end

%w{ apt build-essential git opencsw python ruby_1.9 solaris_omgwtfbbq yum wix 7-zip}.each do |cb|
  depends cb
end
