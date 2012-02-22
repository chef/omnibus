name "automake"
version "1.11.2"

source :url => "http://ftp.gnu.org/gnu/automake/automake-1.11.2.tar.gz",
       :md5 => "79ad64a9f6e83ea98d6964cef8d8a0bc"

relative_path "automake-1.11.2"

configure_env = {
  "LDFLAGS" => "-R/opt/opscode/embedded/lib -L/opt/opscode/embedded/lib -I/opt/opscode/embedded/include",
  "CFLAGS" => "-L/opt/opscode/embedded/lib -I/opt/opscode/embedded/include"
}

build do
  command "./bootstrap"
  command "./configure --prefix=/opt/opscode/embedded"
  command "make"
  command "make install"
end
