name "zlib"
dependencies []

# TODO: this link is subject to change with each new release of zlib.
#       we'll need to use a more robust link (sourceforge) that will
#       not change over time.
source :url => "http://zlib.net/zlib-1.2.6.tar.gz",
       :md5 => "618e944d7c7cd6521551e30b32322f4a"

relative_path "zlib-1.2.6"

configure_env =
  case platform
  when "darwin"
    {
      "LDFLAGS" => "-R/opt/opscode/embedded/lib -L/opt/opscode/embedded/lib -I/opt/opscode/embedded/include",
      "CFLAGS" => "-I/opt/opscode/embedded/include -L/opt/opscode/embedded/lib"
    }
  else
    {
      "LDFLAGS" => "-Wl,-rpath /opt/opscode/embedded/lib -L/opt/opscode/embedded/lib -I/opt/opscode/embedded/include",
      "CFLAGS" => "-I/opt/opscode/embedded/include -L/opt/opscode/embedded/lib"
    }
  end

build do
  command "./configure --prefix=/opt/opscode/embedded", :env => configure_env
  command "make"
  command "make install"
end
