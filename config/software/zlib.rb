name "zlib"
description "teh zlibz"
dependencies []
source :url => "http://zlib.net/zlib-1.2.5.tar.gz",
       :md5 => "c735eab2d659a96e5a594c9e8541ad63"
relative_path "zlib-1.2.5"

# TODO: make this platform-independent, below is only for darwin
configure_env = {
  "LDFLAGS" => "-R/opt/opscode/embedded/lib -L/opt/opscode/embedded/lib -I/opt/opscode/embedded/include",
  "CFLAGS" => "-I/opt/opscode/embedded/include -L/opt/opscode/embedded/lib"
}

build do
  command "./configure --prefix=/opt/opscode/embedded", :env => configure_env
  command "make"
  command "make install"
end
