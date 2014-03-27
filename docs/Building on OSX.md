Building Omnibus Packages for Mac OSX
=====================================
This document details the steps and configurables for building omnibus packages
on Mac OSX. Unlike Linux-based systems, the process for building a `.pkg` and
a `.dmg` requires some manual preparation of assets.


Building a .pkg
---------------
In Mac OSX, a `.pkg` is a special file that is read by Installer.app that
contains the set of instructions for installating a piece of software on a
target system.

### Requirements
The omnibus generator will create some stock files in `files/mac_pkg`:

- `background.png` - the background image for the installer. We recommend this
image has a light background color (otherwise, the text will be difficult to
read).
- `license.html` - the full HTML document for the license
- `welcome.html` - the full HTML document for the welcome screen

You should use these stock files and templates as a starting point for building
your custom pkg.


Building a .dmg
---------------
In Mac OSX, a `.dmg` is a compressed wrapper around a collection of resources,
often including a `.pkg`. The possibilities for creating and customizing a DMG
are endless, but Omnibus provides a "basic" starter case that will generate a
pretty DMG that contains the `.pkg` file it creates.

The following tunables are available:

- `dmg_window_bounds` - the starting and ending (x,y) coordinates for the opened
DMG
- `dmg_pkg_position` - the (x,y) coordinate for the `.pkg` file inside the
opened DMG window

### Requirements
The omnibus generator will create some stock files in `files/mac_dmg`:

- `background.png` - the background image to use for the DMG. We recommend using
a high-resolution image that is slightly larger than the final length of your
window (as determined by the `dmg_window_bounds`)
- `icon.png` - a 1024x1024 @ 300 icon to use for the DMG. We will automatically
create an icns and scale to smaller sizes

You should use these stock files and templates as a starting point for building
your custom dmg.

### Disabling dmg building
DMG creation is enabled by default, but you can disable DMG creation by setting
the `build_dmg` omnibus configuration option to false:

```ruby
# omnibus.rb
build_dmg false
```

And run as you normally would:

```bash
$ ./bin/omnibus build project <name>
```
