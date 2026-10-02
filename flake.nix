{
  description = "supervizio: PID1-capable process supervisor and OpenTelemetry collector agent";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      sources = lib.importJSON ./sources.json;
      # One system per binary the release publishes (sources.json).
      forAllSystems = lib.genAttrs (builtins.attrNames sources.binaries);
    in
    {
      packages = forAllSystems (system: {
        supervizio = nixpkgs.legacyPackages.${system}.callPackage ./package.nix { };
        default = self.packages.${system}.supervizio;
      });

      overlays.default = final: _prev: { supervizio = final.callPackage ./package.nix { }; };

      nixosModules.supervizio = ./module.nix;
      nixosModules.default = self.nixosModules.supervizio;
    };
}
