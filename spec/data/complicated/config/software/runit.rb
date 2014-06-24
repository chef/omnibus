#
# Copyright:: Copyright (c) 2012-2014 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

name "runit"
default_version "2.1.1"

source :url => "http://smarden.org/runit/runit-2.1.1.tar.gz",
       :md5 => "8fa53ea8f71d88da9503f62793336bc3"

relative_path "admin"

working_dir = "#{project_dir}/runit-2.1.1"

build do
  # put runit where we want it, not where they tell us to
  command 'sed -i -e "s/^char\ \*varservice\ \=\"\/service\/\";$/char\ \*varservice\ \=\"' + project.install_path.gsub("/", "\\/") + '\/service\/\";/" src/sv.c', :cwd => working_dir
  # TODO: the following is not idempotent
  command "sed -i -e s:-static:: src/Makefile", :cwd => working_dir

  # build it
  command "make", :cwd => "#{working_dir}/src"
  command "make check", :cwd => "#{working_dir}/src"

  # move it
  command "mkdir -p #{install_path}/embedded/bin"
  ["src/chpst",
   "src/runit",
   "src/runit-init",
   "src/runsv",
   "src/runsvchdir",
   "src/runsvdir",
   "src/sv",
   "src/svlogd",
   "src/utmpset"].each do |bin|
    command "cp #{bin} #{install_path}/embedded/bin", :cwd => working_dir
  end

  block do
    install_path = self.project.install_path
    open("#{install_path}/embedded/bin/runsvdir-start", "w") do |file|
      file.print <<-EOH
#!/bin/bash
#
# Copyright:: Copyright (c) 2012-2014 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

PATH=#{install_path}/bin:#{install_path}/embedded/bin:/usr/local/bin:/usr/local/sbin:/bin:/sbin:/usr/bin:/usr/sbin

# enforce our own ulimits

ulimit -c 0
ulimit -d unlimited
ulimit -e 0
ulimit -f unlimited
ulimit -i 62793
ulimit -l 64
ulimit -m unlimited
# WARNING: increasing the global file descriptor limit increases RAM consumption on startup dramatically
ulimit -n 50000
ulimit -q 819200
ulimit -r 0
ulimit -s 10240
ulimit -t unlimited
ulimit -u unlimited
ulimit -v unlimited
ulimit -x unlimited
echo "1000000" > /proc/sys/fs/file-max

# and our ulimit

umask 022

exec env - PATH=$PATH \
runsvdir -P #{install_path}/service 'log: ...........................................................................................................................................................................................................................................................................................................................................................................................................'
       EOH
    end
  end

  command "chmod 755 #{install_path}/embedded/bin/runsvdir-start"

  # set up service directories
  block do
    ["#{install_path}/service",
     "#{install_path}/sv",
     "#{install_path}/init"].each do |dir|
      FileUtils.mkdir_p(dir)
      # make sure cached builds include this dir
      FileUtils.touch(File.join(dir, '.gitkeep'))
    end
  end
end
