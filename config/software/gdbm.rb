name "gdbm"
version "1.9.1"

dependencies ["autoconf"]

source :url => "http://ftp.gnu.org/gnu/gdbm/gdbm-1.9.1.tar.gz",
       :md5 => "59f6e4c4193cb875964ffbe8aa384b58"

relative_path "gdbm-1.9.1"

build do
  command "/opt/opscode/embedded/bin/autoconf"
  command "./configure --prefix=/opt/opscode/embedded"
  command "make BINOWN=root BINGRP=wheel" # TODO: is this a leftover from os x, a bug?
  command "make install"
end
