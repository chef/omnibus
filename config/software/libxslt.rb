name "libxslt"
dependencies ["libxml2"]

source :url => "ftp://xmlsoft.org/libxml2/libxslt-1.1.26.tar.gz",
       :md5 => "e61d0364a30146aaa3001296f853b2b9"

relative_path "libxslt-1.1.26"

build do
  env = {
    "LDFLAGS" => "-L/opt/opscode/embedded/lib -I/opt/opscode/embedded/include",
    "CFLAGS" => "-L/opt/opscode/embedded/lib -I/opt/opscode/embedded/include",
    "LD_RUN_PATH" => "/opt/opscode/embedded/lib"
  }
  command(["./configure",
           "--prefix=/opt/opscode/embedded",
           "--with-libxml-prefix=/opt/opscode/embedded",
           "--with-libxml-include-prefix=/opt/opscode/embedded/include",
           "--with-libxml-libs-prefix=/opt/opscode/embedded/lib"].join(" "),
          :env => env)
  command "make", :env => {"LD_RUN_PATH" => "/opt/opscode/embedded/bin"}
  command "make install", :env => {"LD_RUN_PATH" => "/opt/opscode/embedded/bin"}
end
