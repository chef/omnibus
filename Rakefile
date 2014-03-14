require 'bundler/setup'
require 'bundler/gem_tasks'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:unit)

require 'rubocop/rake_task'
desc 'Run Ruby style checks'
Rubocop::RakeTask.new(:style)

namespace :travis do
  desc 'Run tests on Travis'
  task ci: ['unit', 'style']
end

task default: ['travis:ci']
