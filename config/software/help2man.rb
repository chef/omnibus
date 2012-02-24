name "help2man"
version "1.40.5"

dependencies []

source :url => "http://ftp.gnu.org/gnu/help2man/help2man-1.40.5.tar.gz",
       :md5 => "75a7d2f93765cd367aab98986a75f88c"

relative_path "help2man-1.40.5"

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
