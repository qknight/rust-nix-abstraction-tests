{
  description = "create2nix test flake";
  inputs = {
    #rust-overlay.url = "github:oxalica/rust-overlay";
    crate2nix.url = "github:nix-community/crate2nix";
    #nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.11";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
  { self, nixpkgs, flake-utils, crate2nix, fenix }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          toolchain = fenix.packages.${system}.stable.defaultToolchain;
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              (final: prev: {
                rustc = toolchain;
                cargo = toolchain;
              })
            ];
          };
          platform_packages = [];
          crate2nix' = pkgs.callPackage (import "${crate2nix}/tools.nix") {};
          #cargoNix = pkgs.callPackage ./Cargo.nix {};
          cargoNix = crate2nix'.appliedCargoNix {
            name = "trunk";
            src = ./.;
          };
        in
        with pkgs;
        rec {
          packages.default = cargoNix.rootCrate.build;
          devShells.default = mkShell {
            buildInputs = [
              #pkgs.rustc
              #pkgs.cargo
            ];
          };
        }
      );
}
