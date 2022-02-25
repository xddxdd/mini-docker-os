{ pkgs, lib, ... }:

let
  inherit (pkgs.pkgsStatic) callPackage;
in
rec {
  docker = callPackage ./docker.nix { };
  dropbear = callPackage ./dropbear.nix { };
  kmod = pkgs.pkgsStatic.kmod.override { inherit zstd; };
  zstd = callPackage ./zstd.nix { };
}
