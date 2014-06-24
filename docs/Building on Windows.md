Building Omnibus Packages for Windows
=====================================
This document describes the requirements and configurables for building
omnibus packages on Windows. Omnibus builds MSI packages on Windows systems.

Requirements
------------
In order to build an omnibus package on Windows you need:

* Open Source Windows Installer Toolset: [WIX](http://wixtoolset.org/)
* In order to use built in semantic versioning:
  [Git for Windows](http://msysgit.github.io/)

MSI Source Files
----------------
In order to create an MSI package, we will need to have some source files that
can be used by WIX toolset to be able to build the MSI. Omnibus creates some
skeletal MSI source files for you to help you get started.

When you execute `omnibus project <<project_name>>` these files will be created
to be able to build MSIs:

```
C:\> omnibus project demo
  ...
  create  omnibus-demo/files/windows_msi/Resources/localization-en-us.wxl.erb
  create  omnibus-demo/files/windows_msi/Resources/parameters.wxi.erb
  create  omnibus-demo/files/windows_msi/Resources/source.wxs
  create  omnibus-demo/files/windows_msi/Resources/assets/LICENSE.rtf
  create  omnibus-demo/files/windows_msi/Resources/assets/banner_background.bmp
  create  omnibus-demo/files/windows_msi/Resources/assets/dialog_background.bmp
  create  omnibus-demo/files/windows_msi/Resources/assets/project.ico
  create  omnibus-demo/files/windows_msi/Resources/assets/project_16x16.ico
  create  omnibus-demo/files/windows_msi/Resources/assets/project_32x32.ico
  ...
```
- `localization-en-us.wxl.erb` => File that contains the strings that are being
  used in the MSI user interface.
- `parameters.wxi.erb` => File that contains the dynamic information needed for
  the MSI e.g. version numbers.
- `assets/LICENSE.rtf` => License text in Rich Text Format that is displayed
  during MSI installation.
- `assets/*.bmp` => Bitmaps that are displayed during installation.
- `assets/*.ico` => Icons that are used in the system for your application.

Omnibus requires `wxl`, `wxs` and `wxi` files to be present on the system in
order to build an MSI. You can also create these files as erb templates and
omnibus will render them before starting building the MSI.

These files are XML files that are created based on Windows WIX Schema. By
default they will package the files under configured `install_path` and present
a UI that lets users to choose an installation location for the packaged files.
You can modify these XML files based on the documentation
  [here](http://wixtoolset.org/documentation/manual/v3/xsd/).

Configurables
-------------
You can use `msi_parameters` DSL option in your Omnibus project files to pass
dynamic information to your MSI source templates. You can specify a hash or a
block for this option. When block is specified, it is executed at the time of
rendering and it is expected to return a hash. Here is an example:

```ruby
# config/projects/my_project.rb
name 'my_project'

...

msi_parameters do
  # Set the upgrade code dynamically
  params = { }
  params[:upgrade_code] = determine_upgrade_code()
  params
end
```

```xml
<!-- files/windows_msi/Resources/parameters.wxi.erb -->

<?xml version="1.0" encoding="utf-8"?>
<Include>
  <!--
    Versioning. These have to be changed for upgrades.
  -->
  <?define VersionNumber="<%= @msi_version %>" ?>
  <?define DisplayVersionNumber="<%= @msi_display_version %>" ?>

  <?define UpgradeCode="<%= msi_parameters[:upgrade_code] %>" ?>
</Include>
```

MSI Creation
------------
To create an MSI you would normally run:

```
C:\> omnibus build project <name>
```
