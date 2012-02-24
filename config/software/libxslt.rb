name "libxslt"
version "1.1.26"

dependencies ["libxml2"]

source :url => "ftp://xmlsoft.org/libxml2/libxslt-1.1.26.tar.gz",
       :md5 => "e61d0364a30146aaa3001296f853b2b9"

relative_path "libxslt-1.1.26"

build do
  env = {
    "LDFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
    "CFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
    "LD_RUN_PATH" => "#{install_dir}/embedded/lib"
  }
  command(["./configure",
           "--prefix=#{install_dir}/embedded",
           "--with-libxml-prefix=#{install_dir}/embedded",
           "--with-libxml-include-prefix=#{install_dir}/embedded/include",
           "--with-libxml-libs-prefix=#{install_dir}/embedded/lib"].join(" "),
          :env => env)
  command "make", :env => {"LD_RUN_PATH" => "#{install_dir}/embedded/bin"}
  command "make install", :env => {"LD_RUN_PATH" => "#{install_dir}/embedded/bin"}
end
