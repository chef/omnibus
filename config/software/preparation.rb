name "preparation"
description "the steps required to preprare the build"

build do
  command "mkdir -p #{install_dir}/embedded/lib"
  command "mkdir -p #{install_dir}/embedded/bin"
  command "mkdir -p #{install_dir}/bin"
end
