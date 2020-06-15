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
  gem "pry-stack_explorer", "~> 0.4.0" # 0.4 allows us to still test Ruby 2.5
end

if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("2.5")
  gem "ohai", "<15"
  gem "activesupport", "~> 5.0"
end
