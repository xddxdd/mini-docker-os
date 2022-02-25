{
  description = "Lan Tian's NixOS Flake";

  inputs = {
    # Common libraries
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    let
      lib = nixpkgs.lib;
      eachSystem = flake-utils.lib.eachSystemMap flake-utils.lib.allSystems;
    in
    {
      defaultPackage = eachSystem (system: (import ./. {
        inherit nixpkgs system;
      }).config.system.build.runvm);

      packages = eachSystem (system: (import ./. {
        inherit nixpkgs system;
      }).config.system.build);
    };
}
