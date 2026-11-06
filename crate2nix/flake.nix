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
          completeToolchain = fenix.packages.${system}.beta.completeToolchain;
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              (final: prev: {
                rust = completeToolchain;
                cargo = completeToolchain;
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
          packages.default = cargoNix.rootCrate.build.override {
            crateOverrides = pkgs.defaultCrateOverrides // {
              # crate2nix's enableFeatures turns the optional dep behind
              # "nodejs = [ dep:serde ]" into a "serde" feature, which cargo
              # does not do. that compiles the lightningcss serde code without
              # smallvec/serde, parcel_selectors/serde and into_owned.
              lightningcss = attrs: {
                features = builtins.filter (f: f != "serde") attrs.features;
              };
            };
          };
          devShells.default = mkShell {
            buildInputs = [
              completeToolchain
              #pkgs.rustc
              #pkgs.cargo
            ];
          };
        }
      );
}
