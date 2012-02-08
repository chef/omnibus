== Installation

Nothing to install here (yet). Move along.

== DSL

=== Software DSL

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

=== Project DSL
