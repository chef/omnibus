name "zlib"
dependencies []

source :url => "http://zlib.net/zlib-1.2.5.tar.gz",
       :md5 => "c735eab2d659a96e5a594c9e8541ad63"

relative_path "zlib-1.2.5"

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
  command "mkdir -p /opt/opscode/embedded/lib" # zlib's make needs this for some reason
  command "./configure --prefix=/opt/opscode/embedded", :env => configure_env
  command "make"
  command "make install"
end
