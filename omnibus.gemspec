# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'omnibus/version'

Gem::Specification.new do |gem|
  gem.name           = 'omnibus'
  gem.version        = Omnibus::VERSION
  gem.license        = 'Apache 2.0'
  gem.author         = 'Chef Software, Inc.'
  gem.email          = 'info@getchef.com'
  gem.description    = 'Omnibus helps you build self-installing, full-stack software builds.'
  gem.summary        = gem.description
  gem.homepage       = 'https://github.com/opscode/omnibus-ruby'

  gem.required_ruby_version = '>= 1.9.1'

  gem.files = `git ls-files`.split($/)
  gem.bindir = 'bin'
  gem.executables = %w(omnibus)
  gem.test_files = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.add_dependency 'chef-sugar',      '~> 1.2'
  gem.add_dependency 'mixlib-shellout', '~> 1.3'
  gem.add_dependency 'mixlib-config',   '~> 2.1'
  gem.add_dependency 'ohai',            '~> 6.12'
  gem.add_dependency 'fpm',             '~> 1.0.0'
  gem.add_dependency 'uber-s3'
  gem.add_dependency 'thor',            '>= 0.16.0'

  gem.add_development_dependency 'rspec',   '~> 2.14'
  gem.add_development_dependency 'rubocop', '~> 0.18'
  gem.add_development_dependency 'rake'

  gem.add_development_dependency 'bundler'
end
