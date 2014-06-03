require 'bundler/gem_tasks'

require 'rspec/core/rake_task'
[:unit, :functional].each do |type|
  RSpec::Core::RakeTask.new(type) do |t|
    t.pattern = "spec/#{type}/**/*_spec.rb"
    t.rspec_opts = [].tap do |a|
      a.push('--color')
      a.push('--format progress')
    end.join(' ')
  end
end

require 'cucumber/rake/task'
Cucumber::Rake::Task.new(:acceptance) do |t|
  t.cucumber_opts = [].tap do |a|
    a.push('--color')
    a.push('--format progress')
    a.push('--strict')
  end.join(' ')
end

namespace :travis do
  desc 'Run tests on Travis'
  task ci: %w(unit acceptance)
end

task default: %w(travis:ci)
