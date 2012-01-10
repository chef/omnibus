name "libiconv"

source :url => 'http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.14.tar.gz',
       :md5 => 'e34509b1623cec449dfeb73d7ce9c6c6'

relative_path "libiconv-1.14"

env = {
  "CFLAGS" => "-L/opt/opscode/embedded/lib -I/opt/opscode/embedded/include",
  "LD_RUN_PATH" => "/opt/opscode/embedded/lib"
}

build do
  command "./configure --prefix=/opt/opscode/embedded", :env => env
  command "make", :env => env
  command "make install"
end
