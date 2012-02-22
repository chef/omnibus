name "ncurses"
version "5.9"

source :url => "http://ftp.gnu.org/gnu/ncurses/ncurses-5.9.tar.gz",
       :md5 => "8cb9c412e5f2d96bc6f459aa8c6282a1"

relative_path "ncurses-5.9"

env = {"LD_RUN_PATH" => "/opt/opscode/embedded/lib"}

build do
  command "./configure --prefix=/opt/opscode/embedded --with-shared --without-debug", :env => env
  command "make", :env => env
  command "make install", :env => env
end
