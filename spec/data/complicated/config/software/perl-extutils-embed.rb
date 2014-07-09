name "perl-extutils-embed"
default_version "1.14"

dependency "perl"

source :url => "http://search.cpan.org/CPAN/authors/id/D/DO/DOUGM/ExtUtils-Embed-#{version}.tar.gz",
       :md5 => "b2a2c26a18bca3ce69f8a0b1b54a0105"

relative_path "ExtUtils-Embed-#{version}"

build do
    command "#{install_dir}/embedded/bin/perl Makefile.PL INSTALL_BASE=#{install_dir}/embedded"
    command "make"
    command "make install"
end
