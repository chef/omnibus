# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'omnibus/version'

Gem::Specification.new do |gem|
  gem.name           = 'omnibus'
  gem.version        = Omnibus::VERSION
  gem.license        = 'Apache 2.0'
  gem.author         = 'Chef Software, Inc.'
  gem.email          = 'releng@getchef.com'
  gem.summary        = 'Omnibus is a framework for building self-installing, full-stack software builds.'
  gem.description    = gem.summary
  gem.homepage       = 'https://github.com/opscode/omnibus'

  gem.required_ruby_version = '>= 1.9.1'

  gem.files = `git ls-files`.split($/)
  gem.bindir = 'bin'
  gem.executables = %w(omnibus)
  gem.test_files = gem.files.grep(/^(test|spec|features)\//)
  gem.require_paths = ['lib']

  gem.add_dependency 'chef-sugar',       '~> 3.0'
  gem.add_dependency 'cleanroom',        '~> 1.0'
  gem.add_dependency 'mixlib-shellout',  '~> 1.4'
  gem.add_dependency 'mixlib-versioning'
  gem.add_dependency 'ohai',             '~> 7.2'
  gem.add_dependency 'ruby-progressbar', '~> 1.7'
  gem.add_dependency 'uber-s3'
  gem.add_dependency 'thor',             '~> 0.18'

  gem.add_development_dependency 'bundler'
  gem.add_development_dependency 'artifactory', '~> 2.0'
  gem.add_development_dependency 'aruba',       '~> 0.5'
  gem.add_development_dependency 'fauxhai',     '~> 2.3'
  gem.add_development_dependency 'rspec',       '~> 3.0'
  gem.add_development_dependency 'rspec-its'
  gem.add_development_dependency 'webmock'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'appbundler'
end
