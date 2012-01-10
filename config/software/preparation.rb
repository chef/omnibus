name "preparation"
description "the steps required to preprare the build"

dependencies []

build do
  command "mkdir -p /opt/opscode/embedded/lib"
  command "mkdir -p /opt/opscode/embedded/bin"
  command "mkdir -p /opt/opscode/bin"
end
