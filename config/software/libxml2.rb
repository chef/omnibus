name "libxml2"
version "2.7.8"

dependencies ["zlib", "libiconv", "readline"]

source :url => "ftp://xmlsoft.org/libxml2/libxml2-2.7.8.tar.gz",
       :md5 => "8127a65e8c3b08856093099b52599c86"

relative_path "libxml2-2.7.8"

build do
  cmd = ["./configure",
         "--prefix=#{install_dir}/embedded",
         "--with-zlib=#{install_dir}/embedded",
         "--with-readline=#{install_dir}/embedded",
         "--with-iconv=#{install_dir}/embedded"].join(" ")
  env = {
    "LDFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
    "CFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
    "LD_RUN_PATH" => "#{install_dir}/embedded/lib"
  }
  command cmd, :env => env
  command "make -j #{max_build_jobs}", :env => {"LD_RUN_PATH" => "#{install_dir}/embedded/lib"}
  command "make install", :env => {"LD_RUN_PATH" => "#{install_dir}/embedded/lib"}
end
