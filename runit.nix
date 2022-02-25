{ pkgs, lib, config, ... }:

let
  compat = pkgs.runCommand "runit-compat" { } ''
    mkdir -p $out/bin/

    cat << EOF > $out/bin/poweroff
    #!/bin/sh
    exec runit-init 0
    EOF

    cat << EOF > $out/bin/reboot
    #!/bin/sh
    exec runit-init 6
    EOF

    chmod +x $out/bin/{poweroff,reboot}
  '';

  dropbear = pkgs.pkgsStatic.callPackage pkgs/dropbear.nix { };
in
{
  environment.systemPackages = [ compat ];
  environment.etc = {
    "runit/1".source = pkgs.writeScript "1" ''
      #!${pkgs.pkgsStatic.busybox}/bin/sh
      ${lib.optionalString config.not-os.simpleStaticIp ''
      ip addr add 10.0.2.15 dev eth0
      ip link set eth0 up
      ip route add 10.0.2.0/24 dev eth0
      ip route add default via 10.0.2.2 dev eth0
      ''}
      mkdir /bin/
      ln -s ${pkgs.pkgsStatic.busybox}/bin/sh /bin/sh

      # disable DPMS on tty's
      echo -ne "\033[9;0]" > /dev/tty0

      touch /etc/runit/stopit
      chmod 0 /etc/runit/stopit
    '';

    "runit/2".source = pkgs.writeScript "2" ''
      #!/bin/sh
      exec runsvdir -P /etc/service
    '';

    "runit/3".source = pkgs.writeScript "3" ''
      #!/bin/sh
    '';

    "service/dropbear/run".source = pkgs.writeScript "sshd_run" ''
      #!/bin/sh
      mkdir -p /root/.ssh
      ln -sf /etc/dropbear/authorized_keys /root/.ssh/authorized_keys
      mkdir -p /etc/dropbear
      ${dropbear}/bin/dropbear -RFmjk
    '';

    "service/nix/run".enable = config.not-os.nix;
    "service/nix/run".source = pkgs.writeScript "nix" ''
      #!/bin/sh
      nix-store --load-db < /nix/store/nix-path-registration
      nix-daemon
    '';
  };
}
