{
  description = "crane test flake";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.11";
    rust-overlay.url = "github:oxalica/rust-overlay";
    crane.url = "github:ipetkov/crane";
  };
  outputs =
  { self, nixpkgs, flake-utils, crane, rust-overlay }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          overlays = [ (import rust-overlay) ];
          pkgs = import nixpkgs {
            inherit system overlays;
          };
          rust = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
          craneLib = crane.mkLib pkgs;
          platform_packages = [];
        in
        with pkgs;
        rec {
          trunk = craneLib.buildPackage rec {
            nativeBuildInputs = [
              pkgs.pkg-config
            ];
            buildInputs = [
              pkgs.openssl
            ];
            src = fetchFromGitHub {
              owner = "trunk-rs";
              repo = "trunk";
              rev = "v0.21.4";
              sha256 = "sha256-tU0Xob0dS1+rrfRVitwOe0K1AG05LHlGPHhFL0yOjxM=";
            };
            cargoTestExtraArgs = "-- --skip=tools::tests::download_and_install_binaries";
          };

          packages.default = trunk;
          devShells.default = mkShell {
            buildInputs = [
              rust
            ];
          };
        }
      );
}
