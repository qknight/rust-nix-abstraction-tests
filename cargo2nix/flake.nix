{
  description = "cargo2nix test flake";
  inputs = {
    cargo2nix = {
      url = "github:cargo2nix/cargo2nix/release-0.11.0";
      inputs.rust-overlay.follows = "rust-overlay";
    };
    flake-utils.follows = "cargo2nix/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.11";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = inputs: with inputs;

  flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ (import rust-overlay) cargo2nix.overlays.default ];
          };
          rust = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
          platform_packages = [];
          rustPkgs = pkgs.rustBuilder.makePackageSet {
            rustVersion = "1.86.0";
            packageFun = import ./Cargo.nix;
          };
        in
        with pkgs;
        rec {
          packages = {
            trunk = (rustPkgs.workspace.trunk {});
            default = packages.trunk;
          };
          devShells.default = mkShell {
            buildInputs = [
              #cargo2nix.cargo2nix
              rust
            ];
          };
        }
      );
}
