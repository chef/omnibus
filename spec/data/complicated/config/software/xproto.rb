
name "xproto"
default_version "7.0.25"

source :url => 'http://xorg.freedesktop.org/releases/individual/proto/xproto-7.0.25.tar.gz',
  :md5 => 'a47db46cb117805bd6947aa5928a7436'

relative_path 'xproto-7.0.25'

configure_env =
  case platform
  when "aix"
    {
      "CC" => "xlc -q64",
      "CXX" => "xlC -q64",
      "LD" => "ld -b64",
      "CFLAGS" => "-q64 -I#{install_dir}/embedded/include -O",
      "LDFLAGS" => "-q64 -Wl,-blibpath:/usr/lib:/lib",
      "OBJECT_MODE" => "64",
      "ARFLAGS" => "-X64 cru",
      "LD" => "ld -b64",
      "OBJECT_MODE" => "64",
      "ARFLAGS" => "-X64 cru "
    }
  when "mac_os_x"
    {
      "LDFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
      "CFLAGS" => "-I#{install_dir}/embedded/include -L#{install_dir}/embedded/lib"
    }
  when "solaris2"
    {
      "LDFLAGS" => "-R#{install_dir}/embedded/lib -L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include -static-libgcc",
      "CFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include"
    }
  else
    {
      "LDFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
      "CFLAGS" => "-I#{install_dir}/embedded/include -L#{install_dir}/embedded/lib"
    }
  end

build do
  command "./configure --prefix=#{install_dir}/embedded", :env => configure_env
  command "make -j #{max_build_jobs}", :env => configure_env
  command "make -j #{max_build_jobs} install", :env => configure_env
end
