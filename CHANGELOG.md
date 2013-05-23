## 1.0.4 (May 23, 2013)

FEATURES:

* Add `release package` command which releases a single package with associated 
  metadata file to a single S3 bucket.
* Arch Linux health check whitelist support

IMPROVEMENTS:

* Add libstdc++ to Mac whitelist libs - this allows the health check pass when 
  depending on C++ libs.
* Change scope of `Omnibus::Library` instance from global to project.

BUG FIXES:

* [CHEF-4214] - projects in multi-project omnibus repositories share dependency scope


## 1.0.3 (May 2, 2013)

FEATURES:

* [CHEF-2576] - SmartOS health check whitelist support
* [CHEF-4141] - FreeBSD health check whitelist support
* [CHEF-3990] - Add support to uncompress zip file

BUG FIXES:

* Fix project homepage in gemspec
* Proper Thor 0.16.0, 0.17.0 suppport - Thor 0.18.0 renamed current_task to
  current_command

## 1.0.2 (April 23, 2013)

IMPROVEMENTS:

* Travis CI support

BUG FIXES:

* [CHEF-4112] `omnibus build project` command does not respect the
  `--no-timestamp` flag

## 1.0.1 (April 21, 2013)

BUG FIXES:

* Vagrant and Berkshelf Vagrant plugin version updates in generated project's
  README.md. Current requirements for the virtualized build lab are:
  * Vagrant 1.2.1+
  * `vagrant-berkshelf` plugin (this was renamed from `berkshelf-vagrant`)

## 1.0.0 (April 21, 2013)

* The initial release.
