Building Omnibus Packages for RHEL
==================================
This document details the steps and configurables for building RPM packages with Omnibus.


Building a .rpm
---------------
### Requirements
Omnibus assumes the existence of the `rpmbuild` command on the build system. The [omnibus cookbook](https://supermarket.getchef.com/cookbooks/omnibus) automatically handles this installation. If you are not using the Omnibus cookbook, you must install the package manually or using another tool.

### Configurables
The following Project values are taken into consideration when building RPMs:

- `build_version`
- `config_file`
- `conflicts`
- `description`
- `exclude`
- `extra_package_files`
- `iteration`
- `maintainer`
- `package_name`
- `package_user`
- `package_group`
- `package_scripts_path`
- `replaces`
- `runtime_dependency`
- `url`

These options are further described in the [`Project` documentation](http://www.rubydoc.info/github/chef/omnibus/Omnibus/Project).

These values are interpolated and evaluated using Omnibus' internal RPM templates. For 99% of users, these templates should be satisfactory. If you encounter an instance where Omnibus' RPM templates do not satisfy a use case, please open an issue.

Because of the unlikelihood of their necessity, Omnibus does not generate rpm-related assets. If you find yourself in a situation where you need to generate highly-customized RPM assets, run the Omnibus new command with the `--rpm-assets` flag:

    $ omnibus new NAME --rpm-assets

**If this is an existing project, be sure to answer "NO" when asked if you want to overwrite existing files!**

With the `--rpm-assets` flag, Omnibus will generate the following "stock" resources in `resources/NAME/rpm`:

- `rpmmacros.erb` - the macros file
- `signing.erb` - a Ruby script for signing RPMs
- `spec.erb` - the ERB for generating the spec

**You should only generate the RPM assets if you cannot set values using attributes!**

### DSL
You can further customize the behavior of the packager using the `package` DSL command in your project definition:

```ruby
# project.rb
name 'hamlet'

package :rpm do
  signing_passphrase 'acbd1234'
end
```

Some DSL methods available include:

| DSL Method           | Description                                 |
| :------------------: | --------------------------------------------|
| `signing_passphrase` | The passphrase to sign the RPM with         |
| `vendor`             | The name of the package producer            |
| `license`            | The default license for the package         |
| `priority`           | The priority for the package                |
| `category`           | The category for this package               |

If you are unfamiliar with any of these terms, you should just accept the defaults. For more information on the purpose of any of these configuration options, please see the RPM spec.

For more information, please see the [`Packager::RPM` documentation](http://www.rubydoc.info/github/chef/omnibus/Omnibus/Packager/RPM).

### Notes on RPM-signing
To sign an RPM, you will need a GPG keypair. You can [create your own signing key](http://www.madboa.com/geek/gpg-quickstart/) or [import an existing one](http://irtfweb.ifa.hawaii.edu/~lockhart/gpg/gpg-cs.html). Omnibus automatically generates an `.rpmmacros` config file for `rpmbuild` that assumes that the real name associated to the GPG key is the same as the name of the project maintainer as specified in your Omnibus config. You can override this by creating your own `.rpmmacros` using the steps above.
