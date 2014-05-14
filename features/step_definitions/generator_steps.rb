require 'aruba/api'

Given(/^I have an omnibus project named "(.+)"$/) do |name|
  create_dir(name)
  cd(name)

  write_file("config/projects/#{name}.rb", <<-EOH.gsub(/^ {4}/, ''))
    name '#{name}'
    maintainer 'Mrs. Maintainer'
    homepage 'https://example.com'
    install_path './local/build/#{name}'

    build_version '1.0.0'

    exclude '\.git*'
    exclude 'bundler\/git'
  EOH

  write_file('omnibus.rb', <<-EOH.gsub(/^ {4}/, ''))
    # Build configuration
    cache_dir              './local/omnibus/cache'
    install_path_cache_dir './local/omnibus/cache/install_path'
    source_dir             './local/omnibus/src'
    build_dir              './local/omnibus/build'
    package_dir            './local/omnibus/pkg'
    package_tmp            './local/omnibus/pkg-tmp'
  EOH
end
