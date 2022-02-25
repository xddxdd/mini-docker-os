{ lib, pkgs, config, ... }:

with lib;

{
  system.build.bootStage2 = pkgs.substituteAll {
    src = ./stage-2-init.sh;
    isExecutable = true;
    path = config.system.path;
    shell = "${pkgs.pkgsStatic.busybox}/bin/sh";
  };
}
