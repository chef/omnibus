# This is an example software definition for a C project.
#
# Lots of software definitions for popular open source software
# already exist in `opscode-omnibus`:
#
#  https://github.com/opscode/omnibus-software/tree/master/config/software
#
name "c-example"
default_version "1.0.0"

dependency "zlib"
dependency "openssl"

source :url => "http://itchy.neckbeard.se/download/c-example-1.0.0.tar.gz",
       :md5 => "8e23151f569fb54afef093ac0695077d"

relative_path 'c-example-1.0.0'

env = {
  "LDFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
  "CFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
  "LD_RUN_PATH" => "#{install_dir}/embedded/lib"
}

build do
  command ["./configure",
           "--prefix=#{install_dir}/embedded",
           "--disable-debug",
           "--enable-optimize",
           "--disable-ldap",
           "--disable-ldaps",
           "--disable-rtsp",
           "--enable-proxy",
           "--disable-dependency-tracking",
           "--enable-ipv6",
           "--without-libidn",
           "--with-ssl=#{install_dir}/embedded",
           "--with-zlib=#{install_dir}/embedded"].join(" "), :env => env

  command "make -j #{max_build_jobs}", :env => env

end
