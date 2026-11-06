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
          overlays = [ (import rust-overlay) cargo2nix.overlays.default ];
          pkgs = import nixpkgs {
            inherit system overlays;
          };
          platform_packages = [];
          rustPkgs = pkgs.rustBuilder.makePackageSet {
            # the same rustc and cargo as the other flakes, see README.md
            rustToolchain = pkgs.symlinkJoin { name = "rust-nixpkgs"; paths = [ pkgs.rustc pkgs.cargo ]; };
            # cargo 1.82 re-resolves the one crate manifest cargo2nix generates
            # and then wants the crates.io index, cargo 1.86 does not
            packageOverrides = pkgs: pkgs.rustBuilder.overrides.all ++ [
              (pkgs.rustBuilder.rustLib.makeOverride {
                overrideAttrs = drv: { CARGO_NET_OFFLINE = "true"; };
              })
            ];
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
              rustc
              #pkgs.rust-bin.stable.latest.default
            ];
          };
        }
      );
}
