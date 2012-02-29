name "zlib"
version "1.2.6"

dependencies []

# TODO: this link is subject to change with each new release of zlib.
#       we'll need to use a more robust link (sourceforge) that will
#       not change over time.
source :url => "http://zlib.net/zlib-1.2.6.tar.gz",
       :md5 => "618e944d7c7cd6521551e30b32322f4a"

relative_path "zlib-1.2.6"

configure_env =
  case platform
  when "darwin"
    {
      "LDFLAGS" => "-R#{install_dir}/embedded/lib -L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
      "CFLAGS" => "-I#{install_dir}/embedded/include -L#{install_dir}/embedded/lib"
    }
  else
    {
      "LDFLAGS" => "-Wl,-rpath #{install_dir}/embedded/lib -L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
      "CFLAGS" => "-I#{install_dir}/embedded/include -L#{install_dir}/embedded/lib"
    }
  end

build do
  command "./configure --prefix=#{install_dir}/embedded", :env => configure_env
  command "make -j #{max_build_jobs}"
  command "make install"
end
