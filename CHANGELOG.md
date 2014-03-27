Omnibus Ruby CHANGELOG
======================

v3.0.0 (TBD)
------------
### New Features

- **No more rake!** Software definitions are incrementally built and cached using git instead. Software dependency build has been rewritten to leverage git caching. This means compiled software definitions are cached, so future Omnibus project builds are much faster. However, this does introduce some potential breaking changes.

  - Project-level software dependencies are built **last**.
  - it is assumed that project-level software dependencies are most frequently changed, and thus Omnibus optimize for such a case.
  - If you have software definitions that hard code `always_build`, you will probably want to turn that off now.
  - Blank directories are not cached. If you would like a blank directory to be cached, add a `.gitkeep` file to the folder.
  - The build order is compiled in a different way, which might result in a different ordered-installation than previous versions of omnibus.
  - For an example of you you might need to update your project, please see [opscode/omnibus-software@02d06a](https://github.com/opscode/omnibus-software/commit/02d06a74c02340b592e1864e7ab843bc14fa352a)

- Support for building DMGs (OSX Disk Images)
- Update generator to create assets for pkg/dmg resources
- There's a fancy new logo
- Added Chef Sugar integration
- Improved documentation
- Improved test coverage

### Bug fixes

- Project generators now include apt/yum as development cookbooks
- Added libc++.1.dylib as a whitelist healthcheck
- Added libgcc_s.so,1 as a whitelist healthcheck on Solaris
- Fix a bug where `extra_package_files` would break FPM

v2.0.1 (March 18, 2014)
-----------------------
- Fix the name of the `pkg` artifact created on OSX
- Fix new Rubocop warnings
- Update generated `Gemfile` to use Omnibus 2.0
- Switch to using Test Kitchen for generated build labs

v2.0.0 (March, 12, 2014)
------------------------
Major changes:
- `version` is now `default_version`
- Added support for multiple software versions and version overrides
- Added support for project-specific overrides
- Added Mac .pkg packaging functionality (DMG coming soon)
- Require Mixlib::Config 2.0

Minor changes:
- Added a new CI pipeline on Travis
- Switch to Ruby 1.9 hash syntaxes

Tiny changes that probably won't affect you:
- `.yardopts` are no longer committed
- `.rspec` is no longer committed
- Updated copyrights to new company name
- Improved test coverage
- Miscellaneous bug fixes

## 1.3.0 (December 6, 2013)

FEATURES:

- Add `build_retries` global config value (still 3 by default). ([@fujin][], [#63][])
- Add support for pre-install scripts. ([@christophermaier][])
- Add support for `*.tar.xz` files. ([@jf647][], [#71][])
- Add `erb` builder command. ([@ohlol][], [#79][])
- Add `package_user`, `package_group` to project definitions for setting
  user and group ownership for of deb/rpm/solaris packages. ([@ohlol][], [#80][])
- Add `config_file` to project definitions for passing `--config-files`
  options to the `fpm` builder commands. ([@christophergeers][], [#85][])

IMPROVEMENTS:

- Bump default cpus to get better throughput when Ohai is wrong. ([@lamont-granquist][])
- Whitelist `libnsl` on Arch Linux. ([@sl4mmy][], [#67][])
- Switch to using pkgmk for Solaris. ([@lamont-granquist][], [#72][])
- Remove make install from c-example. ([@johntdyer][], [#73][])
- Update Vagrantfile template to use provisionerless base boxes. ([@schisamo][], [#74][])
- Allow access to `Omnibus.project_root` in builder blocks. ([@ohlol][], [#78][])
- Refactor how we handle loading dirs for software files. ([@benjaminws][], [#82][])
- Update depdencies: ([@schisamo][], [#86][])
  - fpm 1.0.0
  - mixlib-config 2.1.0
  - mixlib-shellout 1.3.0

BUG FIXES:

- Properly handle `HTTP_PROXY_USER` and `HTTP_PROXY_PASS`. ([@databus23][], [#77][])
- Fix the incorrect error message logged when the Git fetcher failed to
  resolve refs to commits. ([@mumoshu][], [#81][])
- Removin unsupported `config.ssh.max_tries` and `config.ssh.timeout`
  from Vagrantfile template. ([@totally][], [#83][])
- Mention the required Vagrant plugins. ([@jacobvosmaer][], [#70][])

## 1.2.0 (July 12, 2013)

FEATURES:

- Add `whitelist_file` to software DSL. This allows an individual software
  definition to declare files that should be ignored during health checking.

IMPROVEMENTS:

- Raise an exception if a project's dependency is not found.

BUG FIXES:

- Properly load a project's transitive dependencies.
- Ensure a component is only added to a library one time.

## 1.1.1 (July 2, 2013)

BUG FIXES:

- Raise an exception if a patch file is not found.
- Be more explicit about types in CPU computation.
- Include pkg version, iteration, arch for solaris packages.
- Fix assorted typos in CLI output.

## 1.1.0 (June 12, 2013)

FEATURES:

- AIX health check whitelist support
- AIX Backup-File Format (BFF) package support

IMPROVEMENTS:

- Add libstdc++ to SmartOS whitelist libs - this allows the health check pass when
  depending on C++ libs.

BUG FIXES:

- [CHEF-4246] - omnibus cache populate failing

## 1.0.4 (May 23, 2013)

FEATURES:

- Add `release package` command which releases a single package with associated
  metadata file to a single S3 bucket.
- Arch Linux health check whitelist support

IMPROVEMENTS:

- Add libstdc++ to Mac whitelist libs - this allows the health check pass when
  depending on C++ libs.
- Change scope of `Omnibus::Library` instance from global to project.

BUG FIXES:

- [CHEF-4214] - projects in multi-project omnibus repositories share dependency scope

## 1.0.3 (May 2, 2013)

FEATURES:

- [CHEF-2576] - SmartOS health check whitelist support
- [CHEF-4141] - FreeBSD health check whitelist support
- [CHEF-3990] - Add support to uncompress zip file

BUG FIXES:

- Fix project homepage in gemspec
- Proper Thor 0.16.0, 0.17.0 suppport - Thor 0.18.0 renamed current_task to
  current_command

## 1.0.2 (April 23, 2013)

IMPROVEMENTS:

- Travis CI support

BUG FIXES:

- [CHEF-4112] `omnibus build project` command does not respect the
  `--no-timestamp` flag

## 1.0.1 (April 21, 2013)

BUG FIXES:

- Vagrant and Berkshelf Vagrant plugin version updates in generated project's
  README.md. Current requirements for the virtualized build lab are:
  - Vagrant 1.2.1+
  - `vagrant-berkshelf` plugin (this was renamed from `berkshelf-vagrant`)

## 1.0.0 (April 21, 2013)

- The initial release.

<!--- The following link definition list is generated by PimpMyChangelog --->
[#63]: https://github.com/opscode/omnibus-ruby/issues/63
[#67]: https://github.com/opscode/omnibus-ruby/issues/67
[#70]: https://github.com/opscode/omnibus-ruby/issues/70
[#71]: https://github.com/opscode/omnibus-ruby/issues/71
[#72]: https://github.com/opscode/omnibus-ruby/issues/72
[#73]: https://github.com/opscode/omnibus-ruby/issues/73
[#74]: https://github.com/opscode/omnibus-ruby/issues/74
[#77]: https://github.com/opscode/omnibus-ruby/issues/77
[#78]: https://github.com/opscode/omnibus-ruby/issues/78
[#79]: https://github.com/opscode/omnibus-ruby/issues/79
[#80]: https://github.com/opscode/omnibus-ruby/issues/80
[#81]: https://github.com/opscode/omnibus-ruby/issues/81
[#82]: https://github.com/opscode/omnibus-ruby/issues/82
[#83]: https://github.com/opscode/omnibus-ruby/issues/83
[#85]: https://github.com/opscode/omnibus-ruby/issues/85
[#86]: https://github.com/opscode/omnibus-ruby/issues/86
[@benjaminws]: https://github.com/benjaminws
[@christophergeers]: https://github.com/christophergeers
[@christophermaier]: https://github.com/christophermaier
[@databus23]: https://github.com/databus23
[@fujin]: https://github.com/fujin
[@jacobvosmaer]: https://github.com/jacobvosmaer
[@jf647]: https://github.com/jf647
[@johntdyer]: https://github.com/johntdyer
[@lamont-granquist]: https://github.com/lamont-granquist
[@mumoshu]: https://github.com/mumoshu
[@ohlol]: https://github.com/ohlol
[@schisamo]: https://github.com/schisamo
[@sl4mmy]: https://github.com/sl4mmy
[@totally]: https://github.com/totally
