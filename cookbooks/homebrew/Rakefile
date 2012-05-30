require 'rubygems'
require 'chef'
require 'json'

desc "Generate an updated JSON metadata file"
task :metadata do
  cook_meta = Chef::Cookbook::Metadata.new
  cook_meta.from_file('metadata.rb')
  File.open('metadata.json', 'w') do |f|
    f.write(JSON.pretty_generate(cook_meta))
  end
end

desc "Create an archive for uploading to cookbooks.opscode.com"
task :archive do
  sh %{git archive --format=tar --prefix=homebrew/ HEAD |gzip -9 > homebrew.tar.gz}
end
