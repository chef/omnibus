# The Omnibus Build Cache #

The omnibus project includes a project build caching mechanism that
reduces the time it takes to rebuild a project when only a few
components need to be rebuilt.

The cache uses git to snapshot the project tree after each software
component build. The entire contents of the project's `install_path`
is included in the snaphot.

When rebuilding, omnibus walks the linearized component list and
replays the cache until the first item is encountered that needs to be
rebuilt. Items are rebuilt if the code changes (different version or
different git SHA) or if the build instructions change (edit to
config/software/$COMPONENT).

## Location of Cache Data ##

The default location of the cache (which is just a bare git
repository) is
`/var/cache/omnibus/cache/install_path/$INSTALL_PATH`. You can
customize the location of the cache in the `omnibus.rb` config file
using the key `install_path_cache_dir`. For example:

    install_path_cache_dir "/opt/ominbus-caches"

## How It Works ##

Omnibus begins by loading all projects (see
`lib/omnibus.rb#expand_software`). The dependencies of each project
are loaded using `recursively_load_dependency` to capture the
transitive dependencies of a given project dependency. The result is
that each project has a list of components in "install order" such
that all dependencies come before the things that depend on
them. Components are de-duplicated on the way in and not added if
already present (which will occur when two components share a common
dependency).

The actual build order is determined by `library.rb#build_order` which
does a small reordering to ensure that components that are explicitly
listed in the project file come last. Since the first cache miss
causes the system to rebuild everything further to the right in the
component list, you want to have your most frequently changed
components last to minimize rebuild churn.

Lightweight git tags are used as cache keys. After building a
component, a tag name is computed in `install_path_cache.rb#tag`. The
tag name has the format `#{name}-#{version}-#{digest}` where name and
version map to the component that was just built and digest is a
SHA256 value. The digest is computed by string-ifying the name/version
pairs of all components built prior to this component (keeping the
order of course) and prepending the entire contents of the component's
`config/software/$NAME.rb` file. Important aspects of the cache key
scheme:

* A change in the order or in the name/version of component built
  before the component will invalidate the cache key.
* A change in the component's software config (build instructions)
  invalidates the cache. This is done conservatively; the entire file
  contents are included in the digest computation so even a whitespace
  change will invalidate the key.
* A change in the version of the component itself will invalidate the
  key.

You can inspect the cache keys like this:

    git --git-dir=$CACHE_PATH tag -l

You can manually remove a cache entry using `git tag --delete
$TAG`. In theory, you can share the cache among build slaves using
`git clone/fetch`.

When running a build vm on OS X, note that you will likely run into
trouble if you attempt to locate your cache on your local
filesystem if it is not case sensitive.
