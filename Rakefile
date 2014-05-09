require 'bundler/gem_tasks'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:unit) do |t|
  t.pattern = 'spec/unit/**/*_spec.rb'
end
RSpec::Core::RakeTask.new(:functional) do |t|
  t.pattern = 'spec/functional/**/*_spec.rb'
end

require 'cucumber/rake/task'
Cucumber::Rake::Task.new(:acceptance) do |t|
  t.cucumber_opts = [].tap do |a|
    a.push('--color')
    a.push('--format progress')
    a.push('--strict')
  end.join(' ')
end

require 'rubocop/rake_task'
desc 'Run Ruby style checks'
Rubocop::RakeTask.new(:style)

namespace :travis do
  desc 'Run tests on Travis'
  task ci: ['unit', 'acceptance', 'style']
end

task default: ['travis:ci']
