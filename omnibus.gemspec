# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'omnibus/version'

Gem::Specification.new do |gem|
  gem.name           = "omnibus"
  gem.version        = Omnibus::VERSION
  gem.license        = "Apache 2.0"
  gem.author         = "Opscode"
  gem.email          = "info@opscode.com"
  gem.description    = "Omnibus helps you build self-installing, full-stack software builds."
  gem.summary        = gem.description
  gem.homepage       = "https://github.com/opscode/omnibus-ruby"

  gem.required_ruby_version = ">= 1.9.1"

  gem.files = `git ls-files`.split($/)
  gem.bindir = "bin"
  gem.executables = %w(omnibus)
  gem.test_files = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency "mixlib-shellout", "~> 1.0"
  gem.add_dependency "mixlib-config", "~> 1.1.2"
  gem.add_dependency "ohai", ">= 0.6.12"
  gem.add_dependency "rake", ">= 0.9"
  gem.add_dependency "fpm", "~> 0.4.33"
  gem.add_dependency "uber-s3"
  gem.add_dependency "thor", ">= 0.16.0"

  gem.add_development_dependency "rspec"
  gem.add_development_dependency "rspec_junit_formatter"
end
