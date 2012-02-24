name "openssl"
version "1.0.0f"

dependencies ["zlib"]

source :url => "http://www.openssl.org/source/openssl-1.0.0f.tar.gz",
       :md5 => "e358705fb4a8827b5e9224a73f442025"

relative_path "openssl-1.0.0f"

build do
  # configure
  if platform == "darwin"
    command ["./Configure",
             "darwin-x86_64-cc",
             "--prefix=#{install_dir}/embedded",
             "--with-zlib-lib=#{install_dir}/embedded/lib",
             "--with-zlib-include=#{install_dir}/embedded/include",
             "zlib",
             "shared"].join(" ")
  elsif platform == "solaris2"
    command ["./Configure",
             "solaris-x86-gcc",
             "--prefix=#{install_dir}/embedded",
             "--with-zlib-lib=#{install_dir}/embedded/lib",
             "--with-zlib-include=#{install_dir}/embedded/include",
             "zlib",
             "shared",
             "-L#{install_dir}/embedded/lib",
             "-I#{install_dir}/embedded/include",
             "-R#{install_dir}/embedded/lib"].join(" ")
  else
    command(["./config",
             "--prefix=#{install_dir}/embedded",
             "--with-zlib-lib=#{install_dir}/embedded/lib",
             "--with-zlib-include=#{install_dir}/embedded/include",
             "zlib",
             "shared",
             "-L#{install_dir}/embedded/lib",
             "-I#{install_dir}/embedded/include"].join(" "),
            :env => {"LD_RUN_PATH" => "#{install_dir}/embedded/lib"})
  end

  # make and install
  command "make", :env => {"LD_RUN_PATH" => "#{install_dir}/embedded/lib"}
  command "make install"
end
