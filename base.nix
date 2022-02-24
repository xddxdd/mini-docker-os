{ pkgs, config, lib, ... }:

with lib;

{
  options = {
    boot.isContainer = mkOption {
      type = types.bool;
      default = false;
    };
    hardware.firmware = mkOption {
      type = types.listOf types.package;
      default = [ ];
      apply = list: pkgs.buildEnv {
        name = "firmware";
        paths = list;
        pathsToLink = [ "/lib/firmware" ];
        ignoreCollisions = true;
      };
    };
    not-os.nix = mkOption {
      type = types.bool;
      description = "enable nix-daemon and a writeable store";
    };
    not-os.simpleStaticIp = mkOption {
      type = types.bool;
      default = false;
      description = "set a static ip of 10.0.2.15";
    };
  };
  config = {
    environment.systemPackages = lib.optional config.not-os.nix pkgs.nix;
    environment.etc = {
      "nix/nix.conf".enable = config.not-os.nix;
      "nix/nix.conf".source = pkgs.runCommand "nix.conf" { } ''
        extraPaths=$(for i in $(cat ${pkgs.writeReferencesToFile pkgs.stdenv.shell}); do if test -d $i; then echo $i; fi; done)
        cat > $out << EOF
        build-use-sandbox = true
        build-users-group = nixbld
        build-sandbox-paths = /bin/sh=${pkgs.stdenv.shell} $(echo $extraPaths)
        build-max-jobs = 1
        build-cores = 4
        EOF
      '';

      "resolv.conf".text = "nameserver 10.0.2.3";

      # Put shell paths here, or dropbear will ignore them
      shells.text = ''
        /run/current-system/sw/bin/bash
        /run/current-system/sw/bin/sh
      '';

      passwd.text = ''
        root:x:0:0::/root:/run/current-system/sw/bin/sh
      '' + lib.optionalString config.not-os.nix ''
        nixbld1:x:30001:30000:Nix build user 1:/var/empty:/run/current-system/sw/bin/nologin
        nixbld2:x:30002:30000:Nix build user 2:/var/empty:/run/current-system/sw/bin/nologin
        nixbld3:x:30003:30000:Nix build user 3:/var/empty:/run/current-system/sw/bin/nologin
        nixbld4:x:30004:30000:Nix build user 4:/var/empty:/run/current-system/sw/bin/nologin
        nixbld5:x:30005:30000:Nix build user 5:/var/empty:/run/current-system/sw/bin/nologin
        nixbld6:x:30006:30000:Nix build user 6:/var/empty:/run/current-system/sw/bin/nologin
        nixbld7:x:30007:30000:Nix build user 7:/var/empty:/run/current-system/sw/bin/nologin
        nixbld8:x:30008:30000:Nix build user 8:/var/empty:/run/current-system/sw/bin/nologin
        nixbld9:x:30009:30000:Nix build user 9:/var/empty:/run/current-system/sw/bin/nologin
        nixbld10:x:30010:30000:Nix build user 10:/var/empty:/run/current-system/sw/bin/nologin
      '';

      "nsswitch.conf".text = ''
        hosts:     files dns myhostname mymachines
        networks:  files dns
      '';

      group.text = ''
        root:x:0:root
      '' + lib.optionalString config.not-os.nix ''
        nixbld:x:30000:nixbld1,nixbld10,nixbld2,nixbld3,nixbld4,nixbld5,nixbld6,nixbld7,nixbld8,nixbld9
      '';
    };
    boot.kernelParams = [ "systemConfig=${config.system.build.toplevel}" ];
    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages;
    system.build.earlyMountScript = pkgs.writeScript "dummy" "";
    system.build.runvm = pkgs.writeScript "runner" ''
      #!/bin/sh
      qemu-system-x86_64 --enable-kvm -cpu host -name not-os -m 512 \
        -drive index=0,id=drive1,file=${config.system.build.squashfs},readonly,media=cdrom,format=raw,if=virtio \
        -kernel ${config.system.build.kernel}/bzImage -initrd ${config.system.build.initialRamdisk}/initrd -nographic \
        -append "console=ttyS0 ${toString config.boot.kernelParams} quiet panic=-1" -no-reboot \
        -net nic,model=virtio \
        -net user,net=10.0.2.0/24,host=10.0.2.2,dns=10.0.2.3,hostfwd=tcp::2222-:22,hostfwd=tcp:127.0.0.1:2375-:2375 \
        -device virtio-rng-pci
    '';

    system.build.dist = pkgs.runCommand "not-os-dist" { } ''
      mkdir $out
      cp ${config.system.build.squashfs} $out/root.squashfs
      cp ${config.system.build.kernel}/*Image $out/kernel
      cp ${config.system.build.initialRamdisk}/initrd $out/initrd
      echo "${builtins.unsafeDiscardStringContext (toString config.boot.kernelParams)}" > $out/command-line
    '';

    system.activationScripts.users = ''
      # dummy to make setup-etc happy
    '';
    system.activationScripts.groups = ''
      # dummy to make setup-etc happy
    '';

    # nix-build -A system.build.toplevel && du -h $(nix-store -qR result) --max=0 -BM|sort -n
    system.build.toplevel = pkgs.runCommand "not-os"
      {
        activationScript = config.system.activationScripts.script;
      } ''
      mkdir $out
      cp ${config.system.build.bootStage2} $out/init
      substituteInPlace $out/init --subst-var-by systemConfig $out
      ln -s ${config.system.path} $out/sw
      echo "$activationScript" > $out/activate
      substituteInPlace $out/activate --subst-var out
      chmod u+x $out/activate
      unset activationScript
    '';
    # nix-build -A squashfs && ls -lLh result
    system.build.squashfs = pkgs.callPackage (pkgs.path + "/nixos/lib/make-squashfs.nix") {
      storeContents = [ config.system.build.toplevel ];
    };
  };
}
