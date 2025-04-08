{
  description = "create2nix test flake";
  inputs = {
    rust-overlay.url = "github:oxalica/rust-overlay";
    crate2nix.url = "github:nix-community/crate2nix";
  };
  outputs =
  { self, nixpkgs, flake-utils, rust-overlay, crate2nix }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          overlays = [ (import rust-overlay) ];
          pkgs = import nixpkgs {
            inherit system overlays;
          };
          rust = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
          platform_packages = [];
          crate2nix' = pkgs.callPackage (import "${crate2nix}/tools.nix") {};
          cargoNix = crate2nix'.appliedCargoNix {
            name = "my-crate";
            src = ./.;
          };
        in
        with pkgs;
        rec {
          packages.default = cargoNix.rootCrate.build;
          devShells.default = mkShell {
            buildInputs = [
              rust
            ];
          };
        }
      );
}
