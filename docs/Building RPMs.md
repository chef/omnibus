Building RPMs with Omnibus
=====================================
This document details the steps and configurables for building RPMs with Omnibus.


Building an RPM
---------------
### Requirements
`rpmbuild` must be installed on your system.  The [Chef omnibus cookcook](http://github.com/opscode-cookbooks/omnibus) manages this in its [`_packaging` recipe](http://github.com/opscode-cookbooks/omnibus/blob/master/recipes/_packaging.rb).

### Configurables
The following Omnibus configuration options may be used when building RPMs:

- `build_version`
- `config_file`
- `conflicts`
- `description`
- `exclude`
- `extra_package_files`
- `iteration`
- `maintainer`
- `package_user`
- `package_group`
- `package_scripts_path`
- `replaces`
- `runtime_dependency`
- `url`

These options are further described in the [`Project` documentation](http://rubydoc.info/github/opscode/omnibus/Omnibus/Project)

Signing a RPM
---------------
The following tunables can be set in the Omnibus config if you wish to sign an RPM:

- `sign_rpm` - specifies whether an RPM is to be signed (default is `false`)
- `rpm_signing_passphrase` - the passphrase of the GPG key to be used for RPM signing.  ** We recommend generating a special edition of the Omnibus config to be used for signing, then removing it when signing is done. **

### Requirements
To sign an RPM, you will need a GPG keypair. You can [create](http://www.madboa.com/geek/gpg-quickstart/) your own signing key or [import](http://irtfweb.ifa.hawaii.edu/~lockhart/gpg/gpg-cs.html) an existing one.  Omnibus generates a `.rpmmacros` config file for `rpmbuild` that assumes that the real name associated to the GPG key is the same as the name of the project maintainer as specified in your Omnibus config.  You can override this by creating your own `.rpmmacros` config file and putting it in the home directory of the build user.
