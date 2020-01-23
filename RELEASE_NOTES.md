## Omnibus 7.0:

### Deep Signing and Hardened Runtime

When packaging using the pkg packager omnibus will now deep sign all binaries and libraries in the package based of each software definition's bin_dirs and lib_dirs. When siging binaries the hardened runtime is enabled.

## Omnibus 6.0:

### Ruby 2.3+

This project now requires Ruby 2.3 or later.

### Dependency Updates

Dependencies have been loosened to allow for the latest versoins of Ohai / Fauxhai / Chef-sugar as well as many of the development deps in the Gemfile

### FreeBSD 9 EOL

Support for FreeBSD 9.X has been removed as this is no longer a supported FreeBSD release.

### File Source

You can now source from a file using the :file source.

```ruby
version("local_file") do
  source file: "../../my_dir/artifact.zip"
end
```

### Appbundler 0.11 support

This project now supports and requires Appbundler 0.11.