name "autoconf"
version "2.68"
dependencies []

source :url => "http://ftp.gnu.org/gnu/autoconf/autoconf-2.68.tar.gz",
       :md5 => "c3b5247592ce694f7097873aa07d66fe"

relative_path "autoconf-2.68"

env = {
  "LDFLAGS" => "-R#{install_dir}/embedded/lib -L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
  "CFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include"
}

build do
  command "./configure --prefix=#{install_dir}/embedded", :env => env
  command "make"
  command "make install"
end
