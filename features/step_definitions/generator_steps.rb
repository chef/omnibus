require "aruba/api"

Given(/^I have an omnibus project named "(.+)"$/) do |name|
  create_directory(name)
  cd(name)

  # Build target dir must be created
  abs_path = expand_path(".")

  # Single top level output dir
  create_directory("output")

  write_file("config/projects/#{name}.rb", <<-EOH.gsub(/^ {4}/, ""))
    name '#{name}'
    maintainer 'Mrs. Maintainer'
    homepage 'https://example.com'
    install_dir "#{abs_path}/output"

    build_version '1.0.0'

    exclude '\.git*'
    exclude 'bundler\/git'

    # This is necessary for Windows to pass.
    package :msi do
      upgrade_code "102FDF98-B9BF-4CE1-A716-2AB9CBCDA403"
    end
  EOH

  write_file("omnibus.rb", <<-EOH.gsub(/^ {4}/, ""))
    # Build configuration
    append_timestamp false
    cache_dir     '#{abs_path}/local/omnibus/cache'
    git_cache_dir '#{abs_path}/local/omnibus/cache/git_cache'
    source_dir    '#{abs_path}/local/omnibus/src'
    build_dir     '#{abs_path}/local/omnibus/build'
    package_dir   '#{abs_path}/local/omnibus/pkg'
    package_tmp   '#{abs_path}/local/omnibus/pkg-tmp'
  EOH
end

Given(/^I debug$/) do
  require "pry"
end

Given(/^I have a platform mappings file named "(.+)"$/) do |name|
  write_file(name, <<-EOH.gsub(/^ {4}/, ""))
    {
      "ubuntu-10.04": [
        "ubuntu-10.04",
        "ubuntu-12.04",
        "ubuntu-14.04"
      ]
    }
  EOH
end
