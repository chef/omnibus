name "perl_pg_driver"

dependency "perl"
dependency "postgresql" # only because we're compiling DBD::Pg here, too.

# Ensure we install with the properly configured embedded `cpan` client
omnibus_cpan_client = "#{install_dir}/embedded/bin/cpan -j #{cache_dir}/cpan/OmnibusConfig.pm"

build do
  # We're using PostgreSQL as our database engine, so we need the right driver
  command "yes | #{omnibus_cpan_client} DBD::Pg", :env => env
end
