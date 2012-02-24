name "ruby"
version "1.9.2p290"

dependencies ["autoconf", "zlib", "openssl", "ncurses", "readline"]

source :url => 'http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.2-p290.tar.gz',
       :md5 => '604da71839a6ae02b5b5b5e1b792d5eb'

relative_path "ruby-1.9.2-p290"

env =
  case platform
  when "darwin"
    {
      "CFLAGS" => "-arch x86_64 -m64 -L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
      "LDFLAGS" => "-arch x86_64 -R#{install_dir}/embedded/lib -L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include"
    }
  when "solaris2"
    {
      "CFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
      "LDFLAGS" => "-R#{install_dir}/embedded/lib -L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include"
    }
  else
    {
      "CFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
      "LDFLAGS" => "-Wl,-rpath #{install_dir}/embedded/lib -L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include"
    }
  end

build do
  command "#{install_dir}/embedded/bin/autoconf", :env => env
  command "./configure --prefix=#{install_dir}/embedded --with-opt-dir=#{install_dir}/embedded --enable-shared --disable-install-doc", :env => env
  command "make"
  command "make install"
end
