# This is an example software definition for an Erlang project.
#
# Lots of software definitions for popular open source software
# already exist in `opscode-omnibus`:
#
#  https://github.com/opscode/omnibus-software/tree/master/config/software
#
name "erlang-example"
default_version "1.0.0"

dependency "erlang"
dependency "rebar"
dependency "rsync"

source :git => "git://github.com/example/erlang.git"

relative_path "erlang-example"

env = {
  "PATH" => "#{install_dir}/embedded/bin:#{ENV["PATH"]}",
  "LDFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
  "CFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
  "LD_RUN_PATH" => "#{install_dir}/embedded/lib"
}

build do
  command "make distclean", :env => env
  command "make rel", :env => env
  command "mkdir -p #{install_dir}/embedded/service/example-erlang"
  command ["#{install_dir}/embedded/bin/rsync",
           "-a",
           "--delete",
           "--exclude=.git/***",
           "--exclude=.gitignore",
           "./rel/erlang-example/",
           "#{install_dir}/embedded/service/erlang-example/"].join(" ")
  command "rm -rf #{install_dir}/embedded/service/erlang-example/log"
end
