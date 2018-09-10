Building Omnibus Packages for Windows
=====================================
This document details the steps and configurables for building omnibus packages on Windows. Unlike Linux-based systems, the process for building an `.msi` may involve the customization of some assets.


Building an .msi
----------------
In Windows, an `.msi` is a special executable that contains the set of instructions for installating a piece of software on a target system. Please note, Omnibus does not support the creation of `.exe` files.

### Requirements
By default, Omnibus does not generate msi-related assets. To generate the msi assets, run the Omnibus new command with the `--msi-assets` flag:

    $ omnibus new NAME --msi-assets

**If this is an existing project, be sure to answer "NO" when asked if you want to overwrite existing files!**

With the `--msi-assets` flag, Omnibus will generate the following "stock" resources in `resources/NAME/msi`:

- `localization-en-us.wxl.erb` => File that contains the strings that are being used in the MSI user interface
- `parameters.wxi.erb` => File that contains the dynamic information needed for the MSI e.g. version numbers
- `assets/LICENSE.rtf` => License text in Rich Text Format that is displayed during MSI installation
- `assets/*.bmp` => Bitmaps that are displayed during installation
- `assets/*.ico` => Icons that are used in the system for your application

You should use these stock files and templates as a starting point for building your custom msi.

These files are XML files that are created based on Windows WIX Schema. By default they will package the files under configured `install_dir` and present a UI that lets users to choose an installation location for the packaged files. You can modify these XML files based on the [WIX documentation](http://wixtoolset.org/documentation/manual/v3/xsd/).

### DSL
By default, Omnibus will try to build an msi package when executed on a Windows operating system. You can further customize the behavior of the packager using the `package` DSL command in your project definition:

```ruby
# project.rb
name 'hamlet'

package :msi do
  upgrade_code '2CD7259C-776D-4DDB-A4C8-6E544E580AA1'
  parameters {
    'KeyThing' => 'ValueThing'
  }
  localization 'da-dk'
end
```

Note that `upgrade_code` is **required** and will raise an exception if not defined! Once set, this value must persist for all future versions of your package. To generate a GUID in Ruby, run the following command:

```bash
ruby -r securerandom -e "puts SecureRandom.uuid"
```

Some DSL methods available include:

| DSL Method         | Description                                     |
| :----------------: | ------------------------------------------------|
| **`upgrade_code`** | The unique GUID for this package                |
| `parameters`       | And arbirtary list of key-value pairs to render |
| `localization`     | The language to display in the UI               |

For more information, please see the [`Packager::MSI` documentation](http://www.rubydoc.info/github/chef/omnibus/Omnibus/Packager/MSI).
