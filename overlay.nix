{ pkgs, lib, config, ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      btrfs-progs = null;
      e2fsprogs = null;
      lvm2 = null;
      systemd = null;
      systemdMinimal = null;
      xfsprogs = null;

      git = prev.git.override {
        guiSupport = false;
        nlsSupport = false;
        perlSupport = false;
        pythonSupport = false;
        sendEmailSupport = false;
        svnSupport = false;
        withLibsecret = false;
        withManual = false;
        withpcre2 = false;
      };
      openssh = (prev.openssh.override {
        withKerberos = false;
        withFIDO = false;
      }).overrideAttrs (old: { doCheck = false; });
      procps = prev.procps.override { withSystemd = false; };

      dhcpcd = prev.dhcpcd.override { udev = null; };
      util-linux = prev.util-linux.override { systemd = null; };
    })
  ];
}
