name "sqitch"
default_version "0.973"

dependency "perl"

source :url => "http://www.cpan.org/authors/id/D/DW/DWHEELER/App-Sqitch-#{version}.tar.gz",
       :md5 => "0994e9f906a7a4a2e97049c8dbaef584"

relative_path "App-Sqitch-#{version}"

env = {
  "PATH" => "#{install_dir}/embedded/bin:#{ENV["PATH"]}"
}

# Ensure we install with the properly configured embedded `cpan` client
omnibus_cpan_client = "#{install_dir}/embedded/bin/cpan -j #{cache_dir}/cpan/OmnibusConfig.pm"

# See https://github.com/theory/sqitch for more
build do
  command "perl Build.PL", :env => env
  command "./Build installdeps --cpan_client '#{omnibus_cpan_client}'", :env => env
  command "./Build", :env => env
  command "./Build install", :env => env
end
