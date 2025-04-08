{
  description = "cargo2nix test flake";
  inputs = {
    cargo2nix.url = "github:cargo2nix/cargo2nix/release-0.11.0";
    flake-utils.follows = "cargo2nix/flake-utils";
    nixpkgs.follows = "cargo2nix/nixpkgs";
    #rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = inputs: with inputs; # pass through all inputs and bring them into scope

  flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [  cargo2nix.overlays.default ]; # (import rust-overlay)
          };
          #rust = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
          #platform_packages = [];
          rustPkgs = pkgs.rustBuilder.makePackageSet {
            rustVersion = "1.75.0";
            packageFun = import ./Cargo.nix;
          };
        in
        with pkgs;
        rec {
          packages = {
            # replace hello-world with your package name
            hello-world = (rustPkgs.workspace.hello-world {});
            default = packages.hello-world;
          };
          devShells.default = mkShell {
            buildInputs = [
              #rust
            ];
          };
        }
      );
}
