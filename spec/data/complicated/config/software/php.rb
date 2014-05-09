name "php"
default_version "5.3.10"

dependency "zlib"
dependency "pcre"
dependency "libxslt"
dependency "libxml2"
dependency "libiconv"
dependency "openssl"
dependency "gd"

source :url => "http://us.php.net/distributions/php-5.3.10.tar.gz",
       :md5 => "2b3d2d0ff22175685978fb6a5cbcdc13"

relative_path "php-5.3.10"

env = {
  "LDFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
  "CFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
  "LD_RUN_PATH" => "#{install_dir}/embedded/lib"
}

build do
  command(["./configure",
           "--prefix=#{install_dir}/embedded",
           "--without-pear",
           "--with-zlib-dir=#{install_dir}/embedded",
           "--with-pcre-dir=#{install_dir}/embedded",
           "--with-xsl=#{install_dir}/embedded",
           "--with-libxml-dir=#{install_dir}/embedded",
           "--with-iconv=#{install_dir}/embedded",
           "--with-openssl-dir=#{install_dir}/embedded",
           "--with-gd=#{install_dir}/embedded",
           "--enable-fpm",
           "--with-fpm-user=opscode",
           "--with-fpm-group=opscode"].join(" "),
          :env => env)

  command "make -j #{max_build_jobs}", :env => {"LD_RUN_PATH" => "#{install_dir}/embedded/lib"}
  command "make install"
end
