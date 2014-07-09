name "perl"
default_version "5.18.1"

source :url => "http://www.cpan.org/src/5.0/perl-#{version}.tar.gz",
       :md5 => "304cb5bd18e48c44edd6053337d3386d"

relative_path "perl-#{version}"

env = {
  "LDFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
  "CFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
  "LD_RUN_PATH" => "#{install_dir}/embedded/lib"
}

build do
  command [
            "sh Configure",
            "-de",
            "-Dprefix=#{install_dir}/embedded",
            "-Duseshrplib", ## Compile shared libperl
            "-Dusethreads", ## Compile ithread support
            "-Dnoextensions='DB_File GDBM_File NDBM_File ODBM_File'"
           ].join(" "), :env => env
  command "make -j #{max_build_jobs}"
  command "make install", :env => env

  # Ensure we have a sane omnibus-friendly CPAN config. This should be passed
  # to cpan any commands with the `-j` option.
  omnibus_cpan_home = File.join(cache_dir, 'cpan')
  command "mkdir -p #{omnibus_cpan_home}", :env => env
  block do
    open("#{omnibus_cpan_home}/OmnibusConfig.pm", "w") do |file|
      file.print <<-EOH

$CPAN::Config = {
  'build_dir' => q[#{omnibus_cpan_home}/build],
  'cpan_home' => q[#{omnibus_cpan_home}],
  'histfile' => q[#{omnibus_cpan_home}/histfile],
  'keep_source_where' => q[#{omnibus_cpan_home}/sources],
  'prefs_dir' => q[#{omnibus_cpan_home}/prefs],
  'urllist' => [q[http://cpan.llarian.net/], q[http://cpan.mirror.vexxhost.com/], q[http://noodle.portalus.net/CPAN/]],
};
1;
__END__
       EOH
    end
  end
end
