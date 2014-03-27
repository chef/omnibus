![Omnibus Icon](lib/omnibus/assets/README-logo.png) Omnibus
===========================================================
[![Build Status](https://travis-ci.org/opscode/omnibus-ruby.png?branch=master)](https://travis-ci.org/opscode/omnibus-ruby)

Easily create full-stack installers for your project across a variety of platforms.

Seth Chisamore and Christopher Maier of CHEF gave an introductory talk on Omnibus at ChefConf 2013, entitled **Eat the Whole Bowl: Building a Full-Stack Installer with Omnibus**:
  - [Video](http://www.youtube.com/watch?v=q8iJAntXCNY)
  - [Slides](https://speakerdeck.com/schisamo/eat-the-whole-bowl-building-a-full-stack-installer-with-omnibus)

This project is managed by the CHEF Release Engineering team. For more information on the Release Engineering team's contribution, triage, and release process, please consult the [CHEF Release Engineering OSS Management Guide](https://docs.google.com/a/opscode.com/document/d/1oJB0vZb_3bl7_ZU2YMDBkMFdL-EWplW1BJv_FXTUOzg/edit).


Prerequisites
-------------
Omnibus is designed to run with a minimal set of prerequisites. You will need the following:

- Ruby 1.9+
- Bundler


Get Started
-----------
Omnibus provides both a DSL for defining Omnibus projects for your software, as well as a command-line tool for generating installer artifacts from that definition.

To get started, install Omnibus locally on your workstation.

```bash
$ gem install omnibus
```

You can now create an Omnibus project in your current directory by using the project generator feature.

```bash
$ omnibus project $MY_PROJECT_NAME
```

This will generate a complete project skeleton in the directory `omnibus-$MY_PROJECT_NAME`

This minimal project will actually build.

```bash
$ cd omnibus-$MY_PROJECT_NAME
$ bundle install --binstubs
$ bin/omnibus build project $MY_PROJECT_NAME
```

More details can be found in the generated project README file.


More documentation
------------------
If you are creating OSX packages, please see the [OSX-specifc documentation](docs/Building on OSX.md).


Configuration DSL
------------------
Though the template project will build, it won't do anything exciting. For that, you'll need to use the Omnibus DSL to define the specifics of your own application.

### Software
Omnibus "software" files define individual software components that go into making your overall package. They are the building blocks of your application. The Software DSL provides a way to define where to retrieve the software sources, how to build them, and what dependencies they have. These dependencies are also defined in their own Software DSL files, thus forming the basis for a dependency-aware build ordering.

All Software definitions should go in the `config/software` directory of your Omnibus project repository.

CHEF has created software definitions for a number of commonly-needed components, available in the [omnibus-software](https://github.com/opscode/omnibus-software.git)
repository. When you create a new project skeleton using Omnibus, this is automatically added to the project's Gemfile, making all these software definitions available to you.  (If you prefer, however, you can write your own versions of these same definitions in your project repository; local copies in `config/software` have precedence over anything from the `omnibus-software` repository.)

An example:

```ruby
name 'ruby'
default_version '1.9.2-p290'
source url: 'http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-#{version}.tar.gz',
       md5: '604da71839a6ae02b5b5b5e1b792d5eb'

dependency 'zlib'
dependency 'ncurses'
dependency 'openssl'

relative_path "ruby-#{version}"

build do
  command './configure'
  command 'make'
  command 'make install'
end
```

Some of the DSL methods available include:

| DSL Method        | Description                                |
| :---------------: | -------------------------------------------|
| `name`            | The name of the software component (this should come first) |
| `default_version` | The version of the software component      |
| `source`          | Directions to the location of the source   |
| `dependency`      | An Omnibus software-defined component that this software depends on |
| `relative_path`   | The relative path of the extracted tarball |
| `build`           | The build instructions                     |
| `command`         | An individual build step                   |


You can support building multiple verisons of the same software in the same software definition file using the `version` method and giving a block:

```ruby
name 'ruby'
default_version '1.9.2-p290'

version '1.9.2-p290' do
  source url: 'http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-#{version}.tar.gz',
         md5: '604da71839a6ae02b5b5b5e1b792d5eb'
end

version '2.1.1' do
  source url: 'http://ftp.ruby-lang.org/pub/ruby/2.1/ruby-#{version}.tar.gz',
         md5: 'e57fdbb8ed56e70c43f39c79da1654b2'
end
```

Since the software definitions are simply ruby code, you can conditionally execute anything by wrapping it with pure ruby that tests for the version number.

For more DSL methods, please consult the documentation.

### Projects
A Project DSL file defines your actual application; this is the thing you are creating a full-stack installer for in the first place. It provides a means to define the dependencies of the project (again, as specified in Software DSL definition files), as well as ways to set installer package metadata.

All Project definitions (yes, you can have more than one) should go in the `config/projects` directory of your Omnibus project repository.

```ruby
name            'chef-full'
maintainer      'YOUR NAME'
homepage        'http://yoursite.com'

install_path    '/opt/chef'
build_version   '0.10.8'
build_iteration 4

dependency 'chef'
```

Some DSL methods available include:

| DSL Method        | Description                                 |
| :---------------: | --------------------------------------------|
| `name`            | The name of the project                     |
| `install_path`    | The desired install location of the package |
| `build_version`   | The package version                         |
| `build_iteration` | The package iteration number                |
| `dependency`      | An Omnibus software-defined component to include in this package |

For more information, please see the documentation.


Caveats
-------
### A note on builds
As stated above, the generated project skeleton can run "as-is". However, Omnibus determines the platform for which to build an installer based on *the platform it is currently running on*. That is, you can only generate a `.deb` file for Ubuntu if you're actually running Omnibus *on Ubuntu*.

This is currently achieved using [Test Kitchen](http://kitchen.ci), which is included with any newly generated Omnibus project.


### Overrides
The project definitions can override specific software dependencies by passing in `override` to use the correct version:

```ruby
name 'chef-full'
# <snip>

# This will override the default version of "chef"
override :chef, version: '2.1.1'

dependency 'chef'
```

There is no checking that the version override that you supply has been provided in a version override block in the software definition.

### Git caching
As of Omnibus 3.0.0, projects are no longer built using rake. Instead, we have rewritten the software dependencies to leverage git caching. This means we cache compiled software definitions, so future Omnibus project builds are much faster.

For more information on potential breaking changes, please see the CHANGELOG entry for Omnibus 3.0.0.


License
-------
```text
Copyright 2012-2014 Chef Software, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
