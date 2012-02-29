name "automake"
version "1.11.2"

source :url => "http://ftp.gnu.org/gnu/automake/automake-1.11.2.tar.gz",
       :md5 => "79ad64a9f6e83ea98d6964cef8d8a0bc"

relative_path "automake-1.11.2"

configure_env = {
  "LDFLAGS" => "-R#{install_dir}/embedded/lib -L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
  "CFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include"
}

build do
  command "./bootstrap"
  command "./configure --prefix=#{install_dir}/embedded"
  command "make -j #{max_build_jobs}" 
  command "make install"
end
