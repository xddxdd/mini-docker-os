{ lib, pkgs, config, ... }:

with lib;
let
  modules = pkgs.makeModulesClosure {
    rootModules = config.boot.initrd.availableKernelModules ++ config.boot.initrd.kernelModules;
    allowMissing = true;
    kernel = config.system.build.kernel;
    firmware = config.hardware.firmware;
  };
  dhcpcd = pkgs.dhcpcd.override { udev = null; };
  extraUtils = pkgs.runCommandCC "extra-utils"
    {
      buildInputs = [ pkgs.nukeReferences ];
      allowedReferences = [ "out" pkgs.pkgsStatic.busybox ];
    } ''
    set +o pipefail
    mkdir -p $out/bin $out/lib
    ln -s $out/bin $out/sbin

    copy_bin_and_libs() {
      [ -f "$out/bin/$(basename $1)" ] && rm "$out/bin/$(basename $1)"
      cp -pd $1 $out/bin
    }

    # Copy Busybox
    for BIN in ${pkgs.pkgsStatic.busybox}/{s,}bin/*; do
      copy_bin_and_libs $BIN
    done

    # Strip binaries further than normal.
    chmod -R u+w $out
    stripDirs "lib bin" "-s"

    # Make sure that the patchelf'ed binaries still work.
    echo "testing patched programs..."
    $out/bin/ash -c 'echo hello world' | grep "hello world"
    export LD_LIBRARY_PATH=$out/lib
    $out/bin/mount --help 2>&1 | grep -q "BusyBox"
  '';
  shell = "${extraUtils}/bin/sh";
  bootStage1 = pkgs.writeScript "stage1" ''
    #!${shell}
    echo
    echo "[1;32m<<< NotOS Stage 1 >>>[0m"
    echo

    export PATH=${extraUtils}/bin
    mkdir -p /proc /sys /dev /etc/udev /tmp /run/ /lib/ /mnt/ /var/log /etc/plymouth /bin
    mount -t devtmpfs devtmpfs /dev/
    mount -t proc proc /proc
    mount -t sysfs sysfs /sys

    ln -sv ${shell} /bin/sh
    ln -s ${modules}/lib/modules /lib/modules

    for x in ${lib.concatStringsSep " " config.boot.initrd.kernelModules}; do
      modprobe $x
    done

    root=/dev/vda
    realroot=tmpfs
    for o in $(cat /proc/cmdline); do
      case $o in
        systemConfig=*)
          set -- $(IFS==; echo $o)
          sysconfig=$2
          ;;
        root=*)
          set -- $(IFS==; echo $o)
          root=$2
          ;;
        realroot=*)
          set -- $(IFS==; echo $o)
          realroot=$2
          ;;
      esac
    done

    ${config.not-os.preMount}
    mount -t tmpfs root /mnt/ -o mode=755,size=100% || exec ${shell}
    mkdir -p /mnt/nix/store/

    ${if config.not-os.nix then ''
    # make the store writeable
    mkdir -p /mnt/nix/.ro-store /mnt/nix/.overlay-store /mnt/nix/store
    mount $root /mnt/nix/.ro-store -t squashfs
    if [ $realroot = $1 ]; then
      mount tmpfs -t tmpfs /mnt/nix/.overlay-store -o size=1G
    fi
    mkdir -pv /mnt/nix/.overlay-store/work /mnt/nix/.overlay-store/rw
    modprobe overlay
    mount -t overlay overlay -o lowerdir=/mnt/nix/.ro-store,upperdir=/mnt/nix/.overlay-store/rw,workdir=/mnt/nix/.overlay-store/work /mnt/nix/store
    '' else ''
    # readonly store
    mount $root /mnt/nix/store/ -t squashfs
    ''}

    exec env -i $(type -P switch_root) /mnt/ $sysconfig/init
    exec ${shell}
  '';
  initialRamdisk = pkgs.makeInitrd {
    contents = [{ object = bootStage1; symlink = "/init"; }];
  };
in
{
  options = {
    not-os.preMount = mkOption {
      type = types.lines;
      default = "";
    };
    boot.initrd.enable = mkOption {
      type = types.bool;
      default = true;
    };
  };
  config = {
    system.build.bootStage1 = bootStage1;
    system.build.initialRamdisk = initialRamdisk;
    system.build.extraUtils = extraUtils;
    boot.initrd.availableKernelModules = [ ];
    boot.initrd.kernelModules = [ "tun" "loop" "squashfs" ] ++ (lib.optional config.not-os.nix "overlay");
  };
}
