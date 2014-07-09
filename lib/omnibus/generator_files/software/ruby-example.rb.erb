# This is an example software definition for a Ruby project.
#
# Lots of software definitions for popular open source software
# already exist in `opscode-omnibus`:
#
#  https://github.com/opscode/omnibus-software/tree/master/config/software
#
name "ruby-example"
default_version "1.0.0"

dependency "ruby"
dependency "rubygems"
dependency "bundler"
dependency "rsync"

source :git => "git://github.com/example/ruby.git"

relative_path "ruby-example"

build do
  bundle "install --path=#{install_dir}/embedded/service/gem"
  command "mkdir -p #{install_dir}/embedded/service/ruby-example"
  command "#{install_dir}/embedded/bin/rsync -a --delete --exclude=.git/*** --exclude=.gitignore ./ #{install_dir}/embedded/service/ruby-example/"
end
