{ configuration ? import ./configuration.nix, nixpkgs ? <nixpkgs>, extraModules ? [ ], system ? builtins.currentSystem, platform ? null }:

let
  pkgs = import nixpkgs { inherit system; platform = platform; config = { }; };
  pkgsModule = rec {
    _file = ./default.nix;
    key = _file;
    config = {
      nixpkgs.localSystem = { inherit system; };
      nixpkgs.overlays = [
        (final: prev:
          let
            empty = prev.stdenv.mkDerivation {
              pname = "empty";
              version = "1.0.0";
              phases = [ "installPhase" ];
              installPhase = "touch $out";
            };
          in
          {
            systemdMinimal = empty;

            dhcpcd = prev.dhcpcd.override { udev = null; };
            util-linux = prev.util-linux.override { systemd = null; };
          })
      ];
    };
  };
  baseModules = [
    ./activation-script.nix
    ./base.nix
    ./runit.nix
    ./stage-1.nix
    ./stage-2.nix
    ./system-path.nix
    ./systemd-compat.nix

    (nixpkgs + "/nixos/modules/config/sysctl.nix")
    (nixpkgs + "/nixos/modules/misc/assertions.nix")
    (nixpkgs + "/nixos/modules/misc/lib.nix")
    (nixpkgs + "/nixos/modules/misc/nixpkgs.nix")
    (nixpkgs + "/nixos/modules/system/boot/kernel.nix")
    (nixpkgs + "/nixos/modules/system/etc/etc-activation.nix")
    (nixpkgs + "/nixos/modules/system/etc/etc.nix")

    pkgsModule
  ];
  evalConfig = modules: pkgs.lib.evalModules {
    modules = modules ++ baseModules ++ extraModules;
  };
in
evalConfig [
  configuration
]
