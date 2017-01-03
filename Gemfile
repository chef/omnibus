source "https://rubygems.org"
gemspec

# Fork to allow for a recent version of multipart-post.
gem "pedump", git: "https://github.com/ksubrama/pedump", branch: "patch-1"

# Always use license_scout from master
gem "license_scout", github: "chef/license_scout"

# net-ssh 4.x does not work with Ruby 2.2 on Windows. Chef and ChefDK
# are pinned to 3.2 so pinning that here. Only used by fauxhai in this project
gem "net-ssh", "3.2.0"

group :docs do
  gem "yard",          "~> 0.8"
  gem "redcarpet",     "~> 2.2.2"
  gem "github-markup", "~> 0.7"
end
