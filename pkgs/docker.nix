{ pkgs
, lib
  # package dependencies
, stdenv
, buildGoModule
, buildGoPackage
, pkg-config
, glibc
, go
, containerd_1_4
, runc
, tini
, libtool
, sqlite
, clientOnly ? !stdenv.isLinux
, symlinkJoin
, which
}:

with lib;

let
  inherit (pkgs.docker) version rev moby-src;

  docker-runc = buildGoModule rec {
    inherit (pkgs.docker.docker-runc) name version src;
    vendorSha256 = null;

    buildPhase = ''
      patchShebangs .
      make BUILDTAGS= runc
    '';

    installPhase = ''
      install -Dm755 runc $out/bin/runc
    '';
  };

  docker-containerd = buildGoPackage rec {
    inherit (pkgs.docker.docker-containerd) name version src;
    goPackagePath = "github.com/containerd/containerd";

    buildPhase = ''
      cd go/src/${goPackagePath}
      patchShebangs .
      make binaries "BUILDTAGS=no_aufs no_btrfs no_devmapper no_zfs" "VERSION=v${version}" "REVISION=${src.rev}"
    '';

    installPhase = ''
      install -Dm555 bin/* -t $out/bin
    '';
  };

  docker-tini = tini.overrideAttrs (oldAttrs: {
    inherit (pkgs.docker.docker-tini) name version src;

    # Do not remove static from make files as we want a static binary
    postPatch = "";

    NIX_CFLAGS_COMPILE = "-DMINIMAL=ON";
  });

  moby = buildGoPackage rec {
    name = "moby-${version}";
    inherit version;
    inherit docker-runc docker-containerd docker-tini;

    src = moby-src;

    goPackagePath = "github.com/docker/docker";

    nativeBuildInputs = [ pkg-config go libtool ];
    buildInputs = [ sqlite ];

    postPatch = ''
      patchShebangs hack/make.sh hack/make/
    '';

    buildPhase = ''
      export GOCACHE="$TMPDIR/go-cache"
      # build engine
      cd ./go/src/${goPackagePath}
      export AUTO_GOPATH=1
      export DOCKER_GITCOMMIT="${rev}"
      export VERSION="${version}"
      ./hack/make.sh dynbinary
      cd -
    '';

    installPhase = ''
      cd ./go/src/${goPackagePath}
      install -Dm755 ./bundles/dynbinary-daemon/dockerd $out/bin/dockerd

      ln -s ${docker-containerd}/bin/containerd $out/bin/containerd
      ln -s ${docker-containerd}/bin/containerd-shim $out/bin/containerd-shim
      ln -s ${docker-runc}/bin/runc $out/bin/runc
      ln -s ${docker-tini}/bin/tini-static $out/bin/docker-init
    '';

    DOCKER_BUILDTAGS = [
      "exclude_graphdriver_btrfs"
      "exclude_graphdriver_devicemapper"
    ];
  };
in
buildGoPackage ((optionalAttrs (!clientOnly) {

  inherit docker-runc docker-containerd docker-tini moby;

}) // rec {
  inherit version rev;
  inherit (pkgs.docker) pname src;

  goPackagePath = "github.com/docker/cli";

  nativeBuildInputs = [
    pkg-config
    go
    libtool
  ];
  buildInputs = optionals (!clientOnly) [
    sqlite
  ];

  postPatch = ''
    substituteInPlace ./scripts/build/.variables --replace "set -eu" ""
  '';

  # Keep eyes on BUILDTIME format - https://github.com/docker/cli/blob/${version}/scripts/build/.variables
  buildPhase = ''
    export GOCACHE="$TMPDIR/go-cache"

    cd ./go/src/${goPackagePath}
    # Mimic AUTO_GOPATH
    mkdir -p .gopath/src/github.com/docker/
    ln -sf $PWD .gopath/src/github.com/docker/cli
    export GOPATH="$PWD/.gopath:$GOPATH"
    export GITCOMMIT="${rev}"
    export VERSION="${version}"
    export BUILDTIME="1970-01-01T00:00:00Z"
    source ./scripts/build/.variables
    export CGO_ENABLED=1
    go build -tags pkcs11 --ldflags "$LDFLAGS" github.com/docker/cli/cmd/docker
    cd -
  '';

  installPhase = ''
    cd ./go/src/${goPackagePath}
    install -Dm755 ./docker $out/bin/docker
  '' + optionalString (!clientOnly) ''
    # symlink docker daemon to docker cli derivation
    ln -s ${moby}/bin/dockerd $out/bin/dockerd
    ln -s ${docker-containerd}/bin/containerd $out/bin/containerd
    ln -s ${docker-containerd}/bin/containerd-shim $out/bin/containerd-shim
    ln -s ${docker-runc}/bin/runc $out/bin/runc
    ln -s ${docker-tini}/bin/tini-static $out/bin/docker-init
  '';

  # Exposed for tarsum build on non-linux systems (build-support/docker/default.nix)
  inherit moby-src;
})
