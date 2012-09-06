## v0.8.0:

* [COOK-1204] - Make 'add' default action for yum_repository
* [COOK-1351] - option to not make the yum cache (via attribute)
* [COOK-1353] - x86_64 centos path fixes
* [COOK-1414] - recipe for repoforge


## v0.6.2:

* Updated README to remove git diff artifacts.

## v0.6.0:

* Default action for the yum_repository LWRP is now add.
* [COOK-1227] - clear Chefs internal cache after adding new yum repo
* [COOK-1262] - yum::epel should enable existing repo on Amazon Linux
* [COOK-1272], [COOK-1302] - update RPM file for CentOS / RHEL 6
* [COOK-1330] - update cookbook documentation on excludes for yum
* [COOK-1346] - retry remote_file for EPEL in case we get an FTP mirror


## v0.5.2:

* [COOK-825] - epel and ius `remote_file` should notify the `rpm_package` to install

## v0.5.0:

* [COOK-675] - add recipe for handling EPEL repository
* [COOK-722] - add recipe for handling IUS repository

## v.0.1.2:

* Remove yum update in default recipe, that doesn't update caches, it updates packages installed.
