name "git"
default_version "1.9.1"

dependency "curl"
dependency "zlib"
dependency "openssl"
dependency "pcre"
dependency "libiconv"
dependency "expat"
dependency "perl"

relative_path "git-#{version}"

source :url => "https://github.com/git/git/archive/v#{version}.tar.gz",
       :md5 => "906f984f5c8913176547dc456608be16"

env = {
  "LDFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
  "CFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
  "LD_RUN_PATH" => "#{install_dir}/embedded/lib",

  "NO_GETTEXT" => "1",
  "NO_PYTHON" => "1",
  "NO_TCLTK" => "1",
  "NO_R_TO_GCC_LINKER" => "1",
  "NEEDS_LIBICONV" => "1",

  "PERL_PATH" => "#{install_dir}/embedded/bin/perl",
  "ZLIB_PATH" => "#{install_dir}/embedded",
  "ICONVDIR" => "#{install_dir}/embedded",
  "OPENSSLDIR" => "#{install_dir}/embedded",
  "EXPATDIR" => "#{install_dir}/embedded",
  "CURLDIR" => "#{install_dir}/embedded",
  "LIBPCREDIR" => "#{install_dir}/embedded"
}

build do
  command "make -j #{workers} prefix=#{install_dir}/embedded", :env => env
  command "make install prefix=#{install_dir}/embedded", :env => env
end
