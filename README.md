## Get Started

To get started using Omnibus, create a new project and add it to your Gemfile.

```ruby
gem 'omnibus', :git => 'git@github.com/opscode/omnibus-ruby'
```

In your Rakefile, generate the require the Omnibus gem and load your project and software congifurations to generate the tasks.

```ruby
require 'omnibus'

Omnibus.projects('config/projects/*.rb')
Omnibus.software('config/software/*/.rb')
```

If you've already set up software and project configurations, executing `rake -T` prints a list of things that you can build:

```
rake projects:chef                    # build and package chef
rake prokects:chef:software:ruby      # fetch and build ruby
rake projects:chef:software:rubygems  # fetch and build rubygems
rake prokects:chef:software:chef-gem  # fetch and build chef-gem
```

Executing `rake projects:chef` will recursively build all of the dependencies of Chef from scratch. In the case above, Ruby is build first, followed by the installation of Rubygems. Finally, Chef is installed from gems. Executing the top-level project task (projects:chef) also packages the project for distribution on the target platform (e.g. RPM on RedHat-based systems and DEB on Debian-based systems).

## DSL

### Software DSL

Each piece of sofware built by Omnibus is defined with a DSL in the `config/software` subdirectory of the project. The following is a quick desctiption of that DSL.

`name`: The name of the software.

`dependencies`: An ::Array of ::Strings referring to the `name`s of softwares that need to be present before building this piece.

`source`: A ::Hash describing where the source of the software is to be downloaded from. Hash keys are the following:

* URL Downloads
** `:url` The url of the source tarball.
** `:md5' The md5sum of the source tarball.
* Git Downloads
** `:git` The location of the git repository from which to fetch the source code.

`build`: The instructions for building the software.

`command`: A command to execute. This encompasses a single build step.

### Project DSL

## License

See the LICENSE and NOTICE files for more information.

Copyright: Copyright (c) 2012 Opscode, Inc.
License: Apache License, Version 2.0

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.



