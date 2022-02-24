{ config, lib, pkgs, ... }:

# based heavily on https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/config/system-path.nix

with lib;

{
  boot.initrd.kernelModules = [
    "bridge"
    "crc32c-generic"
    "ip_tables"
    "iptable_nat"
    "libcrc32c"
    "nf_conntrack"
    "nf_defrag_ipv4"
    "nf_defrag_ipv6"
    "nf_nat"
    "overlay"
    "veth"
    "x_tables"
    "xt_MASQUERADE"
  ];

  environment.systemPackages = with pkgs; [
    busybox
    docker
    iptables-legacy
    runit
  ];

  environment.etc."service/dockerd/run".source = pkgs.writeScript "run" ''
    #!/bin/sh
    ${pkgs.docker}/bin/dockerd
  '';

  environment.etc."docker/daemon.json".text = builtins.toJSON {
    experimental = true;
    iptables = false;
    storage-driver = "overlay2";
    userland-proxy = false;
  };

  system.activationScripts.iptables = ''
    ${pkgs.iptables-legacy}/bin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
  '';
}
