name "expat"
default_version "2.1.0"

relative_path "expat-2.1.0"

source :url => "http://downloads.sourceforge.net/project/expat/expat/2.1.0/expat-2.1.0.tar.gz?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fexpat%2F&ts=1374730265&use_mirror=iweb",
       :md5 => "dd7dab7a5fea97d2a6a43f511449b7cd"

env = {
  "LDFLAGS" => "-L#{install_path}/embedded/lib -I#{install_path}/embedded/include",
  "CFLAGS" => "-L#{install_path}/embedded/lib -I#{install_path}/embedded/include",
  "LD_RUN_PATH" => "#{install_path}/embedded/lib"
}

build do
  command ["./configure",
           "--prefix=#{install_path}/embedded"].join(" "), :env => env

  command "make -j #{max_build_jobs}", :env => env
  command "make install"
end
