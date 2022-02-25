{ nixpkgs ? <nixpkgs>, extraModules ? [ ], system ? builtins.currentSystem, platform ? null }:

let
  pkgs = import nixpkgs { inherit system; platform = platform; config = { }; };
  pkgsModule = rec {
    _file = ./default.nix;
    key = _file;
    config = {
      nixpkgs.localSystem = { inherit system; };
      not-os.nix = false;
      not-os.simpleStaticIp = true;
      environment.etc = {
        "dropbear/authorized_keys" = {
          text = ''
            ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMcWoEQ4Mh27AV3ixcn9CMaUK/R+y4y5TqHmn2wJoN6i lantian@lantian-lenovo-archlinux
            ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCulLscvKjEeroKdPE207W10MbZ3+ZYzWn34EnVeIG0GzfZ3zkjQJVfXFahu97P68Tw++N6zIk7htGic9SouQuAH8+8kzTB8/55Yjwp7W3bmqL7heTmznRmKehtKg6RVgcpvFfciyxQXV/bzOkyO+xKdmEw+fs92JLUFjd/rbUfVnhJKmrfnohdvKBfgA27szHOzLlESeOJf3PuXV7BLge1B+cO8TJMJXv8iG8P5Uu8UCr857HnfDyrJS82K541Scph3j+NXFBcELb2JSZcWeNJRVacIH3RzgLvp5NuWPBCt6KET1CCJZLsrcajyonkA5TqNhzumIYtUimEnAPoH51hoUD1BaL4wh2DRxqCWOoXn0HMrRmwx65nvWae6+C/7l1rFkWLBir4ABQiKoUb/MrNvoXb+Qw/ZRo6hVCL5rvlvFd35UF0/9wNu1nzZRSs9os2WLBMt00A4qgaU2/ux7G6KApb7shz1TXxkN1k+/EKkxPj/sQuXNvO6Bfxww1xEWFywMNZ8nswpSq/4Ml6nniS2OpkZVM2SQV1q/VdLEKYPrObtp2NgneQ4lzHmAa5MGnUCckES+qOrXFZAcpI126nv1uDXqA2aytN6WHGfN50K05MZ+jA8OM9CWFWIcglnT+rr3l+TI/FLAjE13t6fMTYlBH0C8q+RnQDiIncNwyidQ== lantian@LandeMacBook-Pro.local
          '';
          mode = "0444";
        };
      };
      boot.initrd.kernelModules = [
        "virtio"
        "virtio_pci"
        "virtio_net"
        "virtio_rng"
        "virtio_blk"
        "virtio_console"
      ];
      boot.kernelPackages = pkgs.linuxPackages_latest;
    };
  };
  baseModules = [
    ./activation-script.nix
    ./base.nix
    ./docker.nix
    ./overlay.nix
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
    (nixpkgs + "/nixos/modules/system/etc/etc.nix")

    pkgsModule
  ];
in
pkgs.lib.evalModules {
  modules = baseModules ++ extraModules;
}
