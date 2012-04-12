## Get Started

To get started using Omnibus, create a new project and add it to your Gemfile.

```ruby
gem 'omnibus', :git => 'git@github.com/opscode/omnibus-ruby'
```

In your Rakefile, generate the require the Omnibus gem and load your project and software congifurations to generate the tasks.

```ruby
require 'omnibus'

Omnibus.projects('config/projects/*.rb')
Omnibus.software('config/software/*/.rb')
```

If you've already set up software and project configurations, executing `rake -T` prints a list of things that you can build:

```
rake projects:chef                    # build and package chef
rake prokects:chef:software:ruby      # fetch and build ruby
rake projects:chef:software:rubygems  # fetch and build rubygems
rake prokects:chef:software:chef-gem  # fetch and build chef-gem
```

Executing `rake projects:chef` will recursively build all of the dependencies of Chef from scratch. In the case above, Ruby is build first, followed by the installation of Rubygems. Finally, Chef is installed from gems. Executing the top-level project task (projects:chef) also packages the project for distribution on the target platform (e.g. RPM on RedHat-based systems and DEB on Debian-based systems).

## Configuration DSL

### Software

```ruby
name    "ruby"
version "1.9.2-p290"
source  :url => "http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-#{version}.tar.gz",
        :md5 => "604da71839a6ae02b5b5b5e1b792d5eb"

dependencies ["zlib", "ncurses", "openssl"]

relative_path "ruby-#{version}"

build do
  command "./configure"
  command "make"
  command "make install"
end
```

**name**: The name of the software component.

**version**: The version of the software component.

**source**: Directions to the location of the source.

**dependencies**: A list of components that this software depends on.

**relative_path**: The relative path of the extracted tarball.

**build**: The build instructions.

**command**: An individual build step.

### Projects

```ruby
name            "chef-full"

install_path    "/opt/chef"
build_version   "0.10.8"
build_iteration "4"

dependencies    ["chef"]
```

**name:** The name of the project.

**install_path:** The desired install location of the package.

**build_version:** The package version.

**build_iteration:** The package iteration number.

**dependencies**: A list of software components to include in this package.

## Build Structure

Omnibus creates and stores build arifacts in a direcory tree under `/var/cache/omnnibus`

```
└── /var/cache/omnibus    
    └── cache
    └── src
    └── build
        └── install_path
            └── ruby.latest
            └── ruby.manifest
````

### cache

The `cache` directory caches the download artifacts for software sources. It keeps pristine tarballs and git repositories, depending on the type of sorce specified.

### src

The `src` directory is where the extracted source code for a piece of software lives. When a piece of software needs to be rebuilt, the `src` directory is recreated from the pristine copy in the download cache.

### build

The `build` directory is where Omnibus keeps track of the build artifacts for each piece of software.

__install_path:__ The undersocre-separated installation path of the project being built (e.g. /opt/chef => opt_chef). Segregating build artifacts by installation path allows us to keep track of the builds for the same pieces of software that are installed in two different locations (e.g. building an embedded Ruby for /opt/chef and /opt/ohai).

__*.latest:__ A sentinel file representing the mtime of the newest file in the pristine source tree for a particular piece of software.

__*.manifest:__ A sentinel file representing the mtime of the last successful build for a particular piece of software.

## License

See the LICENSE and NOTICE files for more information.

Copyright: Copyright (c) 2012 Opscode, Inc.
License: Apache License, Version 2.0

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
