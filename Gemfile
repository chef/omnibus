source "https://rubygems.org"

gemspec

group :docs do
  gem "yard"
  gem "redcarpet"
  gem "github-markup"
end

group :debug do
  gem "pry"
  gem "pry-byebug"
  gem "pry-stack_explorer"
end

# this brings in several fixes to rspec-json_expectations that are causing test failures
gem "rspec-json_expectations", git: "https://github.com/tas50/rspec-json_expectations.git"
