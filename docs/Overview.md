# Developer's Guide to Omnibus

## Overview

Omnibus is a command-line tool that helps you define and create trusted OS native packages for software that you want to distribute. Read more about omnibus [here](https://github.com/chef/omnibus/blob/main/README.md).

## Development setup

To setup omnibus for development-
1. Fork and clone the [omnibus repository](https://github.com/chef/omnibus) in GitHub.
1. Ensure you have a recent version of Ruby installed on your system.
1. Run `bundle install` in the repository directory.
1. You will now have the `omnibus` command available in the `./bin` directory.

## Execution Flow

When `omnibus build <project-name>` is run, the execution sequence is as illustrated [here](./Sequence%20Diagram%20-%20Omnibus%20Build.pdf). An omnibus project typically includes one or more dependency software definitions. Common reusable software definitions can be referred from the [omnibus-sotware](https://github.com/chef/omnibus-software) repository. The project specific build steps are defined in a counterpart software definition of the same name, in a `build do ... end` block.

A summary of steps run during project build
1. The client (typically the CLI) loads the project
1. Project 'load' involves loading all software dependency definitions.
1. The 'load' step parses necessary metadata to help determine software source, license information and to apply project specific overrides.
1. Once all software dependencies are successfully loaded for the current OS, the 'build' step commences.
1. The 'build' step is composed of these sub-steps
   * Based on software definition parsed in the 'load' step, license check is run to ensure that the build adheres to relevant terms in dependencies used.
   * After license check is successful, the software source is downloaded or pulled from cache.
   * Each software dependency is built in the order specified across all the definitions. Pre-built binaries may be pulled from cache.
   * Apart from Windows, on Linux, macOS and other OSes, a health check is run to verify no external or system libraries are linked.
   * Once all binaries are ready as part of the payload, the OS native installer package is created and signed.
   * An optional compression step optimizes and 'beautifies' the installer package.
