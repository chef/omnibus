# ![Omnibus Icon](lib/omnibus/assets/README-logo.png) Omnibus

[![Gem Version](http://img.shields.io/gem/v/omnibus.svg)][gem] [![Travis Build Status](http://img.shields.io/travis/chef/omnibus.svg?label=Travis CI)][travis] [![AppVeyor Build Status](http://img.shields.io/appveyor/ci/chef/omnibus.svg?label=AppVeyor)][appveyor]

Easily create full-stack installers for your project across a variety of platforms.

Seth Chisamore and Christopher Maier of CHEF gave an introductory talk on Omnibus at ChefConf 2013, entitled **Eat the Whole Bowl: Building a Full-Stack Installer with Omnibus**:

- [Video](http://www.youtube.com/watch?v=q8iJAntXCNY)
- [Slides](https://speakerdeck.com/schisamo/eat-the-whole-bowl-building-a-full-stack-installer-with-omnibus)

This project is managed by the CHEF Release Engineering team. For more information on the Release Engineering team's contribution, triage, and release process, please consult the [CHEF Release Engineering OSS Management Guide](https://docs.google.com/a/opscode.com/document/d/1oJB0vZb_3bl7_ZU2YMDBkMFdL-EWplW1BJv_FXTUOzg/edit).

## Prerequisites

Omnibus is designed to run with a minimal set of prerequisites. You will need the following:

- Ruby 2.1+
- Bundler

## Get Started

Omnibus provides both a DSL for defining Omnibus projects for your software, as well as a command-line tool for generating installer artifacts from that definition.

To get started, install Omnibus locally on your workstation.

```bash
$ gem install omnibus
```

You can now create an Omnibus project in your current directory by using the project generator feature.

```bash
$ omnibus new $MY_PROJECT_NAME
```

This will generate a complete project skeleton in the directory `omnibus-$MY_PROJECT_NAME`

```bash
$ cd omnibus-$MY_PROJECT_NAME
$ bundle install --binstubs
$ bin/omnibus build $MY_PROJECT_NAME
```

More details can be found in the generated project's README file.

Omnibus determines the platform for which to build an installer based on **the platform it is currently running on**. That is, you can only generate a `.deb` file on a Debian-based system. To alleviate this caveat, the generated project includes a [Test Kitchen](http://kitchen.ci) setup suitable for generating a series of Omnibus projects.

## More documentation

- [Building on Debian](docs/Building on Debian.md)
- [Building on OSX](docs/Building on OSX.md)
- [Building on RHEL](docs/Building on RHEL.md)
- [Building on Windows](docs/Building on Windows.md)
- [Build Cache](docs/Build Cache.md)

## Configuration DSL

Though the template project will build, it will not do anything exciting. For that, you need to use the Omnibus DSL to define the specifics of your application.

### Config

If present, Omnibus will use a top-level configuration file named `omnibus.rb` at the root of your repository. This file is loaded at runtime and includes a number of configuration tunables. Here is an example:

```ruby
# Build locally (instead of /var)
# -------------------------------
base_dir './local'

# Disable git caching
# ------------------------------
use_git_caching false

# Enable S3 asset caching
# ------------------------------
use_s3_caching true
s3_access_key  ENV['S3_ACCESS_KEY']
s3_secret_key  ENV['S3_SECRET_KEY']
s3_bucket      ENV['S3_BUCKET']
```

For more information, please see the [`Config` documentation](http://rubydoc.info/github/opscode/omnibus/Omnibus/Config).

You can tell Omnibus to load a different configuration file by passing the `--config` option to any command:

```shell
$ bin/omnibus --config /path/to/config.rb
```

Finally, you can override a specific configuration option at the command line using the `--override` flag. This takes ultimate precedence over any configuration file values:

```shell
$ bin/omnibus --override use_git_caching:false
```

### Projects

A Project DSL file defines your actual application; this is the thing you are creating a full-stack installer for in the first place. It provides a means to define the dependencies of the project (again, as specified in Software DSL definition files), as well as ways to set installer package metadata.

All project definitions must be in the `config/projects` directory of your Omnibus repository.

```ruby
name            "chef-full"
maintainer      "YOUR NAME"
homepage        "http://yoursite.com"

install_dir     "/opt/chef"
build_version   "0.10.8"
build_iteration 4

dependency "chef"
```

Some DSL methods available include:

   DSL Method     | Description
:---------------: | ----------------------------------------------------------------
     `name`       | The name of the project
  `install_dir`   | The desired install location of the package
 `build_version`  | The package version
`build_iteration` | The package iteration number
  `dependency`    | An Omnibus software-defined component to include in this package
    `package`     | Invoke a packager-specific DSL
   `compress`     | Invoke a compressor-specific DSL

By default a timestamp is appended to the build_version. You can turn this behavior off by setting `append_timestamp` to `false` in your configuration file or using `--override append_timestamp:false` at the command line.

For more information, please see the [`Project` documentation](http://rubydoc.info/github/opscode/omnibus/Omnibus/Project).

### Software

Omnibus "software" files define individual software components that go into making your overall package. They are the building blocks of your application. The Software DSL provides a way to define where to retrieve the software sources, how to build them, and what dependencies they have. These dependencies are also defined in their own Software DSL files, thus forming the basis for a dependency-aware build ordering.

All Software definitions should go in the `config/software` directory of your Omnibus project repository.

Here is an example:

```ruby
name "ruby"
default_version "1.9.2-p290"
source url: "http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-#{version}.tar.gz",
       md5: "604da71839a6ae02b5b5b5e1b792d5eb"

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

DSL Method        | Description
:---------------- | -------------------------------------------------------------------
`name`            | The name of the software component (this should come first)
`default_version` | The version of the software component
`source`          | Directions to the location of the source
`dependency`      | An Omnibus software-defined component that this software depends on
`relative_path`   | The relative path of the extracted tarball
`build`           | The build instructions

For more DSL methods, please consult the [`Software` documentation](http://rubydoc.info/github/chef/omnibus/Omnibus/Software).

Additionally, there are a number of DSL methods available inside the `build` block:

DSL Method          | Description
:------------------ | -------------------------------------------------------------
`command`           | Execute a single shell command
`make`              | Run make (with or without args), using gmake when appropriate
`patch`             | Apply a patch from disk
`workers`           | The maximum number of builders
`windows_safe_path` | Format the path to be safe for shelling out on Windows
`ruby`              | Execute the code as the embedded Ruby
`gem`               | Execute the code as the embedded Rubygems
`bundle`            | Execute the code as the embedded Bundler
`rake`              | Execute the code as the embedded Rake gem
`block`             | Execute Ruby block at build time
`erb`               | Render the given ERB template
`mkdir`             | Create the given directory
`touch`             | Create the given empty file
`delete`            | Remove the given file or directory
`copy`              | Copy a to b
`move`              | Move a to b
`link`              | Link a to b
`sync`              | Copy all files from a to b, removing any union files

For more DSL methods, please consult the [`Builder` documentation](http://rubydoc.info/github/chef/omnibus/Omnibus/Builder).

You can support building multiple versions of the same software in the same software definition file using the `version` method and giving a block:

```ruby
name "ruby"
default_version "1.9.2-p290"

version "1.9.2-p290" do
  source url: "http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-#{version}.tar.gz",
         md5: "604da71839a6ae02b5b5b5e1b792d5eb"
end

version "2.1.1" do
  source url: "http://ftp.ruby-lang.org/pub/ruby/2.1/ruby-#{version}.tar.gz",
         md5: "e57fdbb8ed56e70c43f39c79da1654b2"
end
```

Since the software definitions are simply ruby code, you can conditionally execute anything by wrapping it with pure Ruby that tests for the version number.

#### Sharing software definitions

The easiest way to share organization-wide software is via bundler and Rubygems. For an example software repository, look at Chef's [omnibus-software](https://github.com/chef/omnibus-software). For more information, please see the [Rubygems documentation](http://guides.rubygems.org/publishing/).

It is recommended you use bundler to pull down these gems (as bundler also permits pulling software directly from GitHub):

```ruby
gem 'my-company-omnibus-software'
gem 'omnibus-software', github: 'my-company/omnibus-software'
```

Then add the name of the software to the list of `software_gems` in your Omnibus config:

```ruby
software_gems %w(my-company-omnibus-software omnibus-software)
```

You may also specify local paths on disk (but be warned this may make sharing the project among teams difficult):

```ruby
local_software_dirs %w(/path/to/software /other/path/to/software)
```

For all of these paths, **order matters**, so it is possible to depend on local software version while still retaining a remote software repo. Given the above example, Omnibus will search for a software definition named `foo` in this order:

```text
$PWD/config/software/foo.rb
/path/to/software/config/software/foo.rb
/other/path/to/software/config/software/foo.rb
/Users/sethvargo/.gems/.../my-comany-omnibus-software/config/software/foo.rb
/Users/sethvargo/.gems/.../omnibus-software/config/software/foo.rb
```

The first instance of `foo.rb` that is encountered will be used. Please note that **local** (vendored) softare definitions take precedence!

## Version Manifest

Git-based software definitions may specify branches as their default_version. In this case, the exact git revision to use will be determined at build-time unless a project override (see below) or external version manifest is used. To generate a version manifest use the `omnibus manifest` command:

```
omnibus manifest PROJECT -l warn
```

This will output a JSON-formatted manifest containing the resolved version of every software definition.

## Whitelisting Libraries

Sometimes a platform has libraries that need to be whitelisted so the healthcheck can pass. The whitelist found in the [healthcheck](https://github.com/chef/omnibus/blob/master/lib/omnibus/health_check.rb) code comprises the minimal required for successful builds on supported platforms.

To add your own whitelisted library, simply add the a regex to your software definition in your omnibus project as follows:

```
whitelist_file /libpcrecpp\.so\..+/
```

It is typically a good idea to add a conditional to whitelist based on the specific platform that requires it.

_Warning: You should only add libraries to the whitelist that are guaranteed to be on the system you install to; if a library comes from a non-default package you should instead build it into the package._

## Changelog

STATUS: _EXPERIMENTAL_

`omnibus changelog generate` will generate a changelog for an omnibus project. This command currently assumes:

- version-manifest.json is checked into the project root
- the project is a git repository
- each version is tagged with a SemVer compliant annotated tag
- Any git-based sources are checked out at ../COMPONENT_NAME
- Any commit message line prepended with ChangeLog-Entry: should be added to the changelog.

These assumptions _will_ change as we determine what works best for a number of our projects.

## Caveats

### Overrides

The project definitions can override specific software dependencies by passing in `override` to use the correct version:

```ruby
name "chef-full"
# <snip>

# This will override the default version of "chef"
override :chef, version: "2.1.1"

dependency "chef"
```

**The overridden version must be defined in the associated software!**

### Debugging

By default, Omnibus will log at the `warn` level. You can override this by passing the `--log-level` flag to your Omnibus call:

```shell
$ bin/omnibus build <project> --log-level info # or "debug"
```

### Git caching

by default, Omnibus caches compiled software definitions, so n+1 Omnibus project builds are much faster. This functionality can be disabled by adding the following to your `omnibus.rb`:

```ruby
use_git_caching false
```

## Contributing

For information on contributing to this project see <https://github.com/chef/chef/blob/master/CONTRIBUTING.md>

## License

```text
Copyright 2012-2016 Chef Software, Inc.

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

[appveyor]: https://ci.appveyor.com/project/chef/omnibus
[gem]: https://rubygems.org/gems/omnibus
[travis]: https://travis-ci.org/chef/omnibus
