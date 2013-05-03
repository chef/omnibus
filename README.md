## Omnibus

[![Build Status](https://travis-ci.org/opscode/omnibus-ruby.png?branch=master)](https://travis-ci.org/opscode/omnibus-ruby)
[![Code Climate](https://codeclimate.com/github/opscode/omnibus-ruby.png)](https://codeclimate.com/github/opscode/omnibus-ruby)

Easily create full-stack installers for your project across a variety
of platforms.

Seth Chisamore and Christopher Maier of Opscode gave an introductory
talk on Omnibus at ChefConf 2013, entitled **Eat the Whole Bowl:
Building a Full-Stack Installer with Omnibus**
([video](http://www.youtube.com/watch?v=q8iJAntXCNY),
[slides](https://speakerdeck.com/schisamo/eat-the-whole-bowl-building-a-full-stack-installer-with-omnibus)).

## Prerequisites

Omnibus is designed to run with a minimal set of prerequisites. You'll
need the following:

- Ruby 1.9 or later (http://ruby-lang.org)
- Bundler (http://gembundler.com, http://rubygems.org/gems/bundler)

Though not *strictly* necessary, Vagrant makes using Omnibus easier,
and is highly recommended.
- Vagrant 1.2.1 or later (http://www.vagrantup.com)

## Get Started

Omnibus provides both a DSL for defining Omnibus projects for your
software, as well as a command-line tool for generating installer
artifacts from that definition.

To get started, install Omnibus locally on your workstation.

```
$ gem install omnibus
```

You can now create an Omnibus project in your current directory by
using the project generator feature.

```
$ omnibus project $MY_PROJECT_NAME
```

This will generate a complete project skeleton in the directory
`omnibus-$MY_PROJECT_NAME`

This minimal project will actually build.

``` shell
$ cd omnibus-$MY_PROJECT_NAME
$ bundle install --binstubs
$ bin/omnibus build project $MY_PROJECT_NAME
```

More details can be found in the generated project README file.

## Configuration DSL

Though the template project will build, it won't do anything exciting.
For that, you'll need to use the Omnibus DSL to define the specifics
of your own application.

### Software

Omnibus "software" files define individual software components that go
into making your overall package.  They are the building blocks of
your application.  The Software DSL provides a way to define where to
retrieve the software sources, how to build them, and what
dependencies they have.  These dependencies are also defined in their
own Software DSL files, thus forming the basis for a dependency-aware
build ordering.

All Software definitions should go in the `config/software` directory
of your Omnibus project repository.

Opscode has created software definitions for a number of
commonly-needed components, available in the
[omnibus-software](https://github.com/opscode/omnibus-software.git)
repository.  When you create a new project skeleton using Omnibus,
this is automatically added to the project's Gemfile, making all these
software definitions available to you.  (If you prefer, however, you
can write your own versions of these same definitions in your project
repository; local copies in `config/software` have precedence over
anything from the `omnibus-software` repository.)

An example:

```ruby
name    "ruby"
version "1.9.2-p290"
source  :url => "http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-#{version}.tar.gz",
        :md5 => "604da71839a6ae02b5b5b5e1b792d5eb"

dependency "zlib"
dependency "ncurses"
dependency "openssl"

relative_path "ruby-#{version}"

build do
  command "./configure"
  command "make"
  command "make install"
end
```

Some of the DSL methods available include:

**name**: The name of the software component.

**version**: The version of the software component.

**source**: Directions to the location of the source.

**dependency**: An Omnibus software-defined component that this software depends on.

**relative_path**: The relative path of the extracted tarball.

**build**: The build instructions.

**command**: An individual build step.

For more, consult the documentation.

### Projects

A Project DSL file defines your actual application; this is the thing
you are creating a full-stack installer for in the first place.  It
provides a means to define the dependencies of the project (again, as
specified in Software DSL definition files), as well as ways to set
installer package metadata.

All Project definitions (yes, you can have more than one) should go in
the `config/projects` directory of your Omnibus project repository.

```ruby
name            "chef-full"
maintainer      "YOUR NAME"
homepage        "http://yoursite.com"

install_path    "/opt/chef"
build_version   "0.10.8"
build_iteration 4

dependency "chef"
```

Some DSL methods available include:

**name:** The name of the project.

**install_path:** The desired install location of the package.

**build_version:** The package version.

**build_iteration:** The package iteration number.

**dependency**: An Omnibus software-defined component to include in this package.

For more, see the documentation.

## A Note On Builds

As stated above, the generated project skeleton can run "as-is".
However, Omnibus determines the platform for which to build an
installer based on *the platform it is currently running on*.  That
is, you can only generate a `.deb` file for Ubuntu if you're actually
running Omnibus *on Ubuntu*.

This is currently achieved using [Vagrant](http://www.vagrantup.com).
A valid `Vagrantfile` for generating builds on Ubuntu and Centos
platforms (though Omnibus is not limited to just those!) is created
for each project that you generate using `omnibus project
$MY_PROJECT_NAME`

## License

See the LICENSE and NOTICE files for more information.

Copyright: Copyright (c) 2012--2013 Opscode, Inc.
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
