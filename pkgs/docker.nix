# { lib, callPackage, fetchFromGitHub }:


# let
#   dockerGen =

{ pkgs
, lib
  # package dependencies
, stdenv
, fetchFromGitHub
, buildGoModule
, buildGoPackage
, makeWrapper
, pkg-config
, glibc
, go
, containerd_1_4
, runc
, tini
, libtool
, sqlite
, libselinux
, libseccomp
, libapparmor
, slirp4netns
, nixosTests
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

    nativeBuildInputs = [ pkg-config ];

    buildInputs = [ libselinux libseccomp libapparmor ];

    makeFlags = [ "BUILDTAGS+=seccomp" ];

    buildPhase = ''
      runHook preBuild
      patchShebangs .
      make ${toString makeFlags} runc
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 runc $out/bin/runc
      runHook postInstall
    '';

    passthru.tests = { inherit (nixosTests) cri-o docker podman; };
  };

  docker-containerd = containerd_1_4.overrideAttrs (oldAttrs: {
    inherit (pkgs.docker.docker-containerd) name version src;
    buildInputs = oldAttrs.buildInputs ++ [ libseccomp ];
    buildPhase = ''
      export BUILDTAGS="seccomp no_aufs no_btrfs no_devmapper no_zfs"
    '' + oldAttrs.buildPhase;
  });

  docker-tini = tini.overrideAttrs (oldAttrs: {
    inherit (pkgs.docker.docker-tini) name version src;

    # Do not remove static from make files as we want a static binary
    postPatch = "";

    buildInputs = [ glibc glibc.static ];

    NIX_CFLAGS_COMPILE = "-DMINIMAL=ON";
  });

  moby = buildGoPackage ((optionalAttrs (stdenv.isLinux)) rec {
    name = "moby-${version}";
    inherit version;
    inherit docker-runc docker-containerd docker-tini;

    src = moby-src;

    goPackagePath = "github.com/docker/docker";

    nativeBuildInputs = [ makeWrapper pkg-config go libtool ];
    buildInputs = [ sqlite libseccomp ];

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
      install -Dm755 ./bundles/dynbinary-daemon/dockerd $out/libexec/docker/dockerd

      makeWrapper $out/libexec/docker/dockerd $out/bin/dockerd \
        --prefix PATH : "$out/libexec/docker:$extraPath"

      ln -s ${docker-containerd}/bin/containerd $out/libexec/docker/containerd
      ln -s ${docker-containerd}/bin/containerd-shim $out/libexec/docker/containerd-shim
      ln -s ${docker-runc}/bin/runc $out/libexec/docker/runc
      ln -s ${docker-tini}/bin/tini-static $out/libexec/docker/docker-init
    '';

    DOCKER_BUILDTAGS = [
      "exclude_graphdriver_btrfs"
      "exclude_graphdriver_devicemapper"
    ]
    ++ optional (libseccomp != null) "seccomp";
  });
in
buildGoPackage ((optionalAttrs (!clientOnly) {

  inherit docker-runc docker-containerd docker-tini moby;

}) // rec {
  inherit version rev;
  inherit (pkgs.docker) pname src;

  goPackagePath = "github.com/docker/cli";

  nativeBuildInputs = [
    makeWrapper
    pkg-config
    go
    libtool
  ];
  buildInputs = optionals (!clientOnly) [
    sqlite
    libseccomp
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
    install -Dm755 ./docker $out/libexec/docker/docker

    makeWrapper $out/libexec/docker/docker $out/bin/docker \
      --prefix PATH : "$out/libexec/docker:$extraPath"
  '' + optionalString (!clientOnly) ''
    # symlink docker daemon to docker cli derivation
    ln -s ${moby}/bin/dockerd $out/bin/dockerd
  '';

  passthru.tests = lib.optionals (!clientOnly) { inherit (nixosTests) docker; };

  # Exposed for tarsum build on non-linux systems (build-support/docker/default.nix)
  inherit moby-src;
})
