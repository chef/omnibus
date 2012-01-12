name "libxml2"
dependencies ["zlib", "libiconv", "readline"]

source :url => "ftp://xmlsoft.org/libxml2/libxml2-2.7.8.tar.gz",
       :md5 => "8127a65e8c3b08856093099b52599c86"

relative_path "libxml2-2.7.8"

build do
  cmd = ["./configure",
         "--prefix=/opt/opscode/embedded",
         "--with-zlib=/opt/opscode/embedded",
         "--with-readline=/opt/opscode/embedded",
         "--with-iconv=/opt/opscode/embedded"].join(" ")
  env = {
    "LDFLAGS" => "-L/opt/opscode/embedded/lib -I/opt/opscode/embedded/include",
    "CFLAGS" => "-L/opt/opscode/embedded/lib -I/opt/opscode/embedded/include",
    "LD_RUN_PATH" => "/opt/opscode/embedded/lib"
  }
  command cmd, :env => env
  command "make", :env => {"LD_RUN_PATH" => "/opt/opscode/embedded/lib"}
  command "make install", :env => {"LD_RUN_PATH" => "/opt/opscode/embedded/lib"}
end
