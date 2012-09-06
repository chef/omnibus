# Description

Configures various YUM components on Red Hat-like systems.  Includes
LWRP for managing repositories and their GPG keys.

Based on the work done by Eric Wolfe and Charles Duffy on the
[yumrepo](https://github.com/atomic-penguin/cookbook-yumrepo) cookbook.

# Requirements

RedHat Enterprise Linux 5, and 6 distributions within this platform family.

# Attributes

* `yum['exclude']`
    - An array containing a list of packages to exclude from updates or
      installs.  Wildcards and shell globs are supported.
    - Defaults to an empty exclude list.

* `yum['installonlypkgs']`
    - An array containing a list of packages which should only be
      installed, never updated.
    - Defaults to an empty install-only list.

* `yum['epel_release']`
    - Set the epel release version based on `node['platform_version']`.
    - Defaults to the most current release of EPEL, based on the major
      version of your platform release.

* `yum['ius_release']`
    - Set the IUS release to install.
    - Defaults to the current release of the IUS repo.

# Recipes

## default

The default recipe does nothing.

## yum

Manages the configuration of the `/etc/yum.conf` via attributes.  See
the aforementioned Array attributes `yum['exclude']` and
`yum['installonlypkgs']`.

## epel

Installs the EPEL repository via RPM. Uses the `yum['epel_release']`
attribute to select the right version of the repository package to
install. Also uses the node's platform version (as an integer) for the
major release of EL.

On Amazon Linux, the built-in EPEL repository is activated using
`yum-config-manager --quiet --enable epel`. This ignores the
`node['yum']['epel_release']` attribute in favor of the version
configured in the Amazon Linux AMI.

## ius

Installs the [IUS Community repositories](http://iuscommunity.org/Repos)
via RPM. Uses the `node['yum']['ius_release']` attribute to select the
right versino of the package to install.

The IUS repository requires EPEL, and includes `yum::epel` as a
dependency.

# Resources/Providers

## key

This LWRP handles importing GPG keys for YUM repositories. Keys can be
imported by the `url` parameter or placed in `/etc/pki/rpm-gpg/` by a
recipe and then installed with the LWRP without passing the URL.

### Actions

- :add: installs the GPG key into `/etc/pki/rpm-gpg/`
- :remove: removes the GPG key from `/etc/pki/rpm-gpg/`

#### Attribute Parameters

- key: name attribute. The name of the GPG key to install.
- url: if the key needs to be downloaded, the URL providing the download.

#### Example

``` ruby
# add the Zenoss GPG key
yum_key "RPM-GPG-KEY-zenoss" do
  url "http://dev.zenoss.com/yum/RPM-GPG-KEY-zenoss"
  action :add
end

# remove Zenoss GPG key
yum_key "RPM-GPG-KEY-zenoss" do
  action :remove
end
```

### repository

This LWRP provides an easy way to manage additional YUM repositories.
GPG keys can be managed with the `key` LWRP.  The LWRP automatically
updates the package management cache upon the first run, when a new
repo is added.

#### Actions

- :add: creates a repository file and builds the repository listing (default)
- :remove: removes the repository file

#### Attribute Parameters

- repo_name: name attribute. The name of the channel to discover
- description. The description of the repository
- url: The URL providing the packages
- mirrorlist: Default is `false`,  if `true` the `url` is considered a list of mirrors
- key: Optional, the name of the GPG key file installed by the `key` LWRP.

- enabled: Default is `1`, set to `0` if the repository is disabled.
- type: Optional, alternate type of repository
- failovermethod: Optional, failovermethod
- bootstrapurl: Optional, bootstrapurl
- make_cache: Optional, Default is `true`, if `false` then `yum -q makecache` will not be ran

### Example

``` ruby
# add the Zenoss repository
yum_repository "zenoss" do
  name "Zenoss Stable repo"
  url "http://dev.zenoss.com/yum/stable/"
  key "RPM-GPG-KEY-zenoss"
  action :add
end

# remove Zenoss repo
yum_repository "zenoss" do
  action :remove
end
```

# Usage

Put `recipe[yum::yum]` in the run list to ensure yum is configured
correctly for your environment within your Chef run.

Use the `yum::epel` recipe to enable EPEL, or the `yum::ius` recipe to
enable IUS, per __Recipes__ section above.

You can manage GPG keys either with cookbook_file in a recipe if you
want to package it with a cookbook or use the `url` parameter of the
`key` LWRP.

# License and Author

Author:: Eric G. Wolfe
Author:: Matt Ray (<matt@opscode.com>)
Author:: Joshua Timberman (<joshua@opscode.com>)

Copyright:: 2010 Tippr Inc.
Copyright:: 2011 Eric G. Wolfe
Copyright:: 2011 Opscode, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
