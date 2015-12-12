# -*- encoding: utf-8 -*-
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "omnibus/version"

Gem::Specification.new do |gem|
  gem.name           = "omnibus"
  gem.version        = Omnibus::VERSION
  gem.license        = "Apache 2.0"
  gem.author         = "Chef Software, Inc."
  gem.email          = "releng@getchef.com"
  gem.summary        = "Omnibus is a framework for building self-installing, full-stack software builds."
  gem.description    = gem.summary
  gem.homepage       = "https://github.com/opscode/omnibus"

  gem.required_ruby_version = ">= 2.1"

  gem.files = `git ls-files`.split($/)
  gem.bindir = "bin"
  gem.executables = %w{omnibus}
  gem.test_files = gem.files.grep(/^(test|spec|features)\//)
  gem.require_paths = ["lib"]

  # https://github.com/ksubrama/pedump, branch 'patch-1'
  # is declared in the Gemfile because of its outdated
  # dependency on multipart-post (~> 1.1.4)
  gem.add_dependency "chef-sugar",       "~> 3.3"
  gem.add_dependency "cleanroom",        "~> 1.0"
  gem.add_dependency "mixlib-shellout",  "~> 2.0"
  gem.add_dependency "mixlib-versioning"
  gem.add_dependency "ohai",             "~> 8.0"
  gem.add_dependency "ruby-progressbar", "~> 1.7"
  gem.add_dependency "aws-sdk",          "~> 2"
  gem.add_dependency "thor",             "~> 0.18"
  gem.add_dependency "ffi-yajl",         "~> 2.2"
  gem.add_dependency "license_scout"
  gem.add_dependency 'httparty'

  gem.add_development_dependency "bundler"
  gem.add_development_dependency "artifactory", "~> 2.0"
  gem.add_development_dependency "aruba",       "~> 0.5"
  gem.add_development_dependency "chefstyle",   "~> 0.3"
  gem.add_development_dependency "fauxhai",     "~> 3.2"
  gem.add_development_dependency "rspec",       "~> 3.0"
  gem.add_development_dependency "rspec-json_expectations"
  gem.add_development_dependency "rspec-its"
  gem.add_development_dependency "webmock"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "appbundler"
  gem.add_development_dependency "pry"
end
