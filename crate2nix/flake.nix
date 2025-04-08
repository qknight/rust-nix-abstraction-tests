{
  description = "create2nix test flake";
  inputs = {
    rust-overlay.url = "github:oxalica/rust-overlay";
  };
  outputs =
  { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          overlays = [ (import rust-overlay) ];
          pkgs = import nixpkgs {
            inherit system overlays;
          };
          rust = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
          platform_packages = [];
        in
        with pkgs;
        rec {
          trunk = pkgs.callPackage ./trunk.nix {};
          devShells.default = mkShell {
            buildInputs = [
              rust
            ];
          };
        }
      );
}
