Building Omnibus Packages for Debian
====================================
This document details the steps and configurables for building DEB packages with Omnibus.


Building a .deb
---------------
### Requirements
Omnibus assumes the existence of the `fakeroot` and `dpkg-deb` command on the build system. The [omnibus cookbook](https://supermarket.getchef.com/cookbooks/omnibus) automatically handles this installation. If you are not using the Omnibus cookbook, you must install these packages manually or using another tool.

### Configurables
A number of project configuration values are taken into consideration for building Debian packages. These options are further described in the [`Project` documentation](http://rubydoc.info/github/opscode/omnibus/Omnibus/Project).

These values are interpolated and evaluated using Omnibus' internal DEB templates. For 99% of users, these templates should be satisfactory. If you encounter an instance where Omnibus' ERB templates do not satisfy a use case, please open an issue.

Because of the unlikelihood of their necessity, Omnibus does not generate deb-related assets. If you find yourself in a situation where you need to generate highly-customized DEB assets, run the Omnibus new command with the `--deb-assets` flag:

    $ omnibus new NAME --deb-assets

**If this is an existing project, be sure to answer "NO" when asked if you want to overwrite existing files!**

With the `--deb-assets` flag, Omnibus will generate the following "stock" resources in `resources/NAME/deb`:

- `conffiles.erb` - the list of configuration files
- `control.erb` - the Debian spec file
- `md5sums.erb` - the ERB for generating the list of file checksums

**You should only generate the DEB assets if you cannot set values using attributes!**

### DSL
You can further customize the behavior of the packager using the `package` DSL command in your project definition:

```ruby
# project.rb
name 'hamlet'

package :deb do
  vendor 'Company <company@example.com>'
  license 'Apache 2.0'
  priority 'extra'
  section 'databases'
  gpg_key_name 'Maintainer <maintainer@example.com>'
  signing_passphrase 'acbd1234'
end
```

Some DSL methods available include:

| DSL Method           | Description                                                                  |
| :------------------: | -----------------------------------------------------------------------------|
| `gpg_key_name`       | The name of the key to sign the DEB with (defaults to value of `maintainer`) |
| `signing_passphrase` | The passphrase to sign the DEB with                                          |
| `vendor`             | The name of the package producer                                             |
| `license`            | The default license for the package                                          |
| `priority`           | The priority for the package                                                 |
| `section`            | The section for this package                                                 |

If you are unfamilar with any of these terms, you should just accept the defaults. For more information on the purpose of any of these configuration options, please see the DEB spec.

For more information, please see the [`Packager::DEB` documentation](http://rubydoc.info/github/opscode/omnibus/Omnibus/Packager/DEB).

### Notes on DEB-signing
To sign an DEB, you will need a GPG keypair. You can [create your own signing key](http://www.madboa.com/geek/gpg-quickstart/) or [import an existing one](http://irtfweb.ifa.hawaii.edu/~lockhart/gpg/gpg-cs.html).
