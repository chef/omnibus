name "libiconv"
version "1.14"

source :url => 'http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.14.tar.gz',
       :md5 => 'e34509b1623cec449dfeb73d7ce9c6c6'

relative_path "libiconv-1.14"

env = {
  "CFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
  "LD_RUN_PATH" => "#{install_dir}/embedded/lib"
}

build do
  command "./configure --prefix=#{install_dir}/embedded", :env => env
  command "make -j #{max_build_jobs}", :env => env
  command "make install"
end
