{
  description = "Mobile NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;

      pkgsFor = system: import nixpkgs { inherit system; };

      packagesFor = system:
        let
          pkgs = pkgsFor system;
          docs = import ./doc { inherit pkgs; };
        in
        {
          inherit docs;
          default = docs;
        };
    in
    {
      packages = forAllSystems packagesFor;

      devShells = forAllSystems (system: {
        default = import ./shell.nix { pkgs = pkgsFor system; };
      });

      checks = forAllSystems (system: {
        docs = self.packages.${system}.docs;
      });

      overlays.default = import ./overlay/overlay.nix;

      lib = {
        evalWithConfiguration = import ./lib/eval-with-configuration.nix;
        releaseTools = import ./lib/release-tools.nix;
      };
    };
}
