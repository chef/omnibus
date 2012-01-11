name "openssl"

dependencies ["zlib"]

source :url => "http://www.openssl.org/source/openssl-1.0.0f.tar.gz",
       :md5 => "e358705fb4a8827b5e9224a73f442025"

relative_path "openssl-1.0.0f"

build do
  # configure
  if platform == "darwin"
    command ["./Configure",
             "darwin-x86_64-cc",
             "--prefix=/opt/opscode/embedded",
             "--with-zlib-lib=/opt/opscode/embedded/lib",
             "--with-zlib-include=/opt/opscode/embedded/include",
             "zlib",
             "shared"].join(" ")
  elsif platform == "solaris2"
    command ["./Configure",
             "solaris-x86-gcc",
             "--prefix=/opt/opscode/embedded",
             "--with-zlib-lib=/opt/opscode/embedded/lib",
             "--with-zlib-include=/opt/opscode/embedded/include",
             "zlib",
             "shared",
             "-L/opt/opscode/embedded/lib",
             "-I/opt/opscode/embedded/include",
             "-R/opt/opscode/embedded/lib"].join(" ")
  else
    command(["./config",
             "--prefix=/opt/opscode/embedded",
             "--with-zlib-lib=/opt/opscode/embedded/lib",
             "--with-zlib-include=/opt/opscode/embedded/include",
             "zlib",
             "shared",
             "-L/opt/opscode/embedded/lib",
             "-I/opt/opscode/embedded/include"].join(" "),
            :env => {"LD_RUN_PATH" => "/opt/opscode/embedded/lib"})
  end

  # make and install
  command "make", :env => {"LD_RUN_PATH" => "/opt/opscode/embedded/lib"}
  command "make install"
end
