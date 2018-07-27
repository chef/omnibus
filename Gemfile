source "https://rubygems.org"
gemspec


gem "license_scout",  git: 'https://github.com/chef/license_scout', branch: 'ma/fixup_breaks'

# net-ssh 4.x does not work with Ruby 2.2 on Windows. Chef and ChefDK
# are pinned to 3.2 so pinning that here. Only used by fauxhai in this project
gem "net-ssh", "3.2.0"

group :docs do
  gem "yard",          "~> 0.9"
  gem "redcarpet",     "~> 2.2.2"
  gem "github-markup", "~> 0.7"
end
