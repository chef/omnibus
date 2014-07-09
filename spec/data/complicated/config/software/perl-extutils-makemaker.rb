name "perl-extutils-makemaker"
default_version "6.78"

dependency "perl"

source :url => "http://search.cpan.org/CPAN/authors/id/B/BI/BINGOS/ExtUtils-MakeMaker-#{version}.tar.gz",
       :md5 => "843886bc1060b5e5c619e34029343eba"

relative_path "ExtUtils-MakeMaker-#{version}"

build do
    command "#{install_dir}/embedded/bin/perl Makefile.PL INSTALL_BASE=#{install_dir}/embedded"
    command "make"
    command "make install"
end
