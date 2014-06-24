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
  "LDFLAGS" => "-L#{install_path}/embedded/lib -I#{install_path}/embedded/include",
  "CFLAGS" => "-L#{install_path}/embedded/lib -I#{install_path}/embedded/include",
  "LD_RUN_PATH" => "#{install_path}/embedded/lib",

  "NO_GETTEXT" => "1",
  "NO_PYTHON" => "1",
  "NO_TCLTK" => "1",
  "NO_R_TO_GCC_LINKER" => "1",
  "NEEDS_LIBICONV" => "1",

  "PERL_PATH" => "#{install_path}/embedded/bin/perl",
  "ZLIB_PATH" => "#{install_path}/embedded",
  "ICONVDIR" => "#{install_path}/embedded",
  "OPENSSLDIR" => "#{install_path}/embedded",
  "EXPATDIR" => "#{install_path}/embedded",
  "CURLDIR" => "#{install_path}/embedded",
  "LIBPCREDIR" => "#{install_path}/embedded"
}

build do
  command "make -j #{max_build_jobs} prefix=#{install_path}/embedded", :env => env
  command "make install prefix=#{install_path}/embedded", :env => env
end
