name "ruby"
dependencies ["autoconf"]

source :url => 'http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.2-p290.tar.gz',
       :md5 => '604da71839a6ae02b5b5b5e1b792d5eb'

relative_path "ruby-1.9.2-p290"

# TODO make this cross platform
env = {
  "CFLAGS" => "-arch x86_64 -m64 -L/opt/opscode/embedded/lib -I/opt/opscode/embedded/include",
  "LDFLAGS" => "-arch x86_64 -R/opt/opscode/embedded/lib -L/opt/opscode/embedded/lib -I/opt/opscode/embedded/include"
}

build do
  command "/opt/opscode/embedded/bin/autoconf", :env => env
  command "./configure --prefix=/opt/opscode/embedded --with-opt-dir=/opt/opscode/embedded --enable-shared --disable-install-doc", :env => env
  command "make"
  command "make install"
end
