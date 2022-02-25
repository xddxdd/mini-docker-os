{ stdenv
, pkgs
, zlib
, sftpPath ? "/run/current-system/sw/libexec/sftp-server"
}:

stdenv.mkDerivation rec {
  inherit (pkgs.dropbear) pname version src patches;

  configureFlags = [ "LDFLAGS=-static" ];

  CFLAGS = "-DSFTPSERVER_PATH=\\\"${sftpPath}\\\"";

  # https://www.gnu.org/software/make/manual/html_node/Libraries_002fSearch.html
  preConfigure = ''
    makeFlags=VPATH=`cat $NIX_CC/nix-support/orig-libc`/lib
  '';

  buildInputs = [ zlib zlib.static ];
}
