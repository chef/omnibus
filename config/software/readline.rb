name "readline"
version "6.2"

# NOTE: the clojure omnibus uses readline 5.2, which is super old.
# there might be a reason for that, and if this doesn't build on other
# platforms then we might need to go back to using the old version
source :url => 'http://ftp.gnu.org/gnu/readline/readline-6.2.tar.gz',
       :md5 => '67948acb2ca081f23359d0256e9a271c'

relative_path "readline-6.2"

configure_env =
  case platform
  when "darwim"
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
  command "./configure --prefix=#{install_dir}/embedded", :env => configure_env
  command "make"
  command "make install"
end
