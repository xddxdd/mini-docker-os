{ config, lib, pkgs, ... }:

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
    lantian.docker
    pkgsStatic.busybox
    pkgsStatic.iptables-legacy
    pkgsStatic.runit
  ];

  environment.etc."service/dockerd/run".source = pkgs.writeScript "run" ''
    #!/bin/sh
    ${pkgs.lantian.docker}/bin/dockerd
  '';

  environment.etc."docker/daemon.json".text = builtins.toJSON {
    experimental = true;
    hosts = [ "unix:///var/run/docker.sock" "tcp://0.0.0.0:2375" ];
    iptables = false;
    storage-driver = "overlay2";
    tls = false;
    userland-proxy = false;
  };

  system.activationScripts.iptables = ''
    ${pkgs.pkgsStatic.iptables-legacy}/bin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
  '';
}
