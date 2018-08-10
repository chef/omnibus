Building Omnibus Packages for Mac OS X
======================================
This document details the steps and configurables for building omnibus packages on Mac OS X. Unlike Linux-based systems, the process for building a `.pkg` (and compressing with `.dmg`) may involve the customization of some assets.


Building a .pkg
---------------
In Mac OS X, a `.pkg` is a special file that is read by Installer.app that contains the set of instructions for installing a piece of software on a target system.

### Requirements
By default, Omnibus does not generate pkg-related assets. To generate the pkg assets, run the Omnibus new command with the `--pkg-assets` flag:

    $ omnibus new NAME --pkg-assets

**If this is an existing project, be sure to answer "NO" when asked if you want to overwrite existing files!**

With the `--pkg-assets` flag, Omnibus will generate the following "stock" resources in `resources/NAME/pkg`:

- `background.png` - the background image for the installer. We recommend this
image has a light background color (otherwise, the text will be difficult to
read).
- `distribution.xml.erb` - the XML file for use during the `productbuild` command
- `license.html.erb` - the full HTML document for the license
- `welcome.html.erb` - the full HTML document for the welcome screen

You should use these stock files and templates as a starting point for building your custom pkg.

### DSL
By default, Omnibus will try to build a pkg package when executed on a Mac OS X operating system. You can further customize the behavior of the packager using the `package` DSL command in your project definition:

```ruby
# project.rb
name 'hamlet'

package :pkg do
  identifier 'com.getchef.hamlet'
  signing_identity 'acbd1234'
end
```

Some DSL methods available include:

| DSL Method         | Description                                 |
| :----------------: | --------------------------------------------|
| `identifier`       | The `com.whatever` id for the package       |
| `signing_identity` | The key to sign the PKG with                |

For more information, please see the [`Packager::PKG` documentation](http://rubydoc.info/github/chef/omnibus/Omnibus/Packager/PKG).


Building a .dmg
---------------
In Mac OSX, a `.dmg` is a compressed wrapper around a collection of resources, often including a `.pkg`. The possibilities for creating and customizing a DMG are endless, but Omnibus provides a"basic starter case that will generate a pretty DMG that contains the `.pkg` file it creates.

### Requirements
By default, Omnibus does not generate dmg-related assets. To generate the dmg assets, run the Omnibus new with the `--dmg-assets` flag:

    $ omnibus new NAME --dmg-assets

**If this is an existing project, be sure to answer "NO" when asked if you want to overwrite existing files!**

With the `--dmg-assets` flag, Omnibus will generate the following "stock" resources in `resources/NAME/dmg`:

- `background.png` - the background image to use for the DMG. We recommend using
a high-resolution image that is slightly larger than the final length of your
window (as determined by the `dmg_window_bounds`)
- `icon.png` - a 1024x1024 @ 300 icon to use for the DMG. We will automatically
create an icns and scale to smaller sizes

You should use these stock files and templates as a starting point for building your custom dmg.

### DSL
By default, Omnibus will **not** try to build a compressed dmg. You can enable this compression using the `compress` DSL command in your project definition:

```ruby
# project.rb
name 'hamlet'

compress :dmg do
  window_bounds '200, 200, 750, 600'
  pkg_position '10, 10'
end
```

Some DSL methods available include:

| DSL Method         | Description                                 |
| :----------------: | --------------------------------------------|
| `window_bounds`    | The size and location of the DMG window     |
| `pkg_position`     | The position of the pkg inside the DMG      |

For more information, please see the [`Compressor::DMG` documentation](http://www.rubydoc.info/github/chef/omnibus/Omnibus/Compressor/DMG).
