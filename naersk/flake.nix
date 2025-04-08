{
  description = "naersk test flake";
  inputs = {
    rust-overlay.url = "github:oxalica/rust-overlay";
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.11";
    naersk.url = "github:nix-community/naersk";
  };
  outputs =
  { self, nixpkgs, flake-utils, rust-overlay, naersk }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          overlays = [ (import rust-overlay) ];
          pkgs = import nixpkgs {
            inherit system overlays;
          };
          naersk' = pkgs.callPackage naersk {};
          rust = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
          platform_packages = [];
        in
        with pkgs;
        rec {
          trunk = naersk'.buildPackage {
            pname = "trunk";
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
            cargo_test_options = "--skip=tools::tests::download_and_install_binaries";
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
