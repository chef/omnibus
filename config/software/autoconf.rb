name "autoconf"
version "2.68"
dependencies []

source :url => "http://ftp.gnu.org/gnu/autoconf/autoconf-2.68.tar.gz",
       :md5 => "c3b5247592ce694f7097873aa07d66fe"

relative_path "autoconf-2.68"

env = {
  "LDFLAGS" => "-R/opt/opscode/embedded/lib -L/opt/opscode/embedded/lib -I/opt/opscode/embedded/include",
  "CFLAGS" => "-L/opt/opscode/embedded/lib -I/opt/opscode/embedded/include"
}

build do
  command "./configure --prefix=/opt/opscode/embedded", :env => env
  command "make"
  command "make install"
end
