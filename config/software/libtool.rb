name "libtool"
version "2.4"

source :url => "http://ftp.gnu.org/gnu/libtool/libtool-2.4.tar.gz",
       :md5 => "b32b04148ecdd7344abc6fe8bd1bb021"

relative_path "libtool-2.4"

make_command =
  case platform
  when "solaris2", "freebsd"
    "qmake"
  else
    "make"
  end

build do
  command "./configure --prefix=#{install_dir}/embedded"
  command make_command
  command "#{make_command} install"
end
