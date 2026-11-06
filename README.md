# what is this

a test environment to learn about:

* cargo2nix 
* crane 
* crate2nix 
* naersk

# status

all four build `trunk` 0.21.4 with the versions pinned in each `flake.lock`, and the resulting `trunk --version` runs.

* naersk 
* crane
* cargo2nix
* crate2nix

# comparison

measured with the `flake.nix`/`flake.lock` in this repo on x86_64-linux, 'old' rustc/cargo, no `nix flake update`.

| | crane | naersk | cargo2nix | crate2nix |
|---|---|---|---|---|
| store entry per crate download | yes (471) | yes (471) | yes (383) | yes (357) |
| store entry per crate build | no (one `trunk-deps`) | no (one `trunk-deps`) | yes (384) | yes (358) |
| custom registries | yes: download url, git index, sparse | no: `cratesDownloadUrl` only moves the crates.io url | yes: git index, you have to pass `fetchCrateAlternativeRegistry` | sparse only, only with a generated `Cargo.nix` |
| IFD free | yes, with a pure `src` | yes, with a pure `src` | yes | yes, with a generated `Cargo.nix` |
| also via IFD | yes, `src` from a derivation | yes, `src` from a derivation | no built-in way | yes, `tools.nix` |
| support tool | no | no | `cargo2nix` creates `Cargo.nix` | `crate2nix` creates `Cargo.nix` |
| rustc which built `trunk` | 1.82.0, nixpkgs | 1.82.0, nixpkgs | 1.82.0, nixpkgs | 1.82.0, nixpkgs |

notes:

* the numbers count per crate derivations in `nix path-info --derivation --recursive .#default`. crane and naersk download everything in `Cargo.lock` (471 crates.io packages), cargo2nix and crate2nix only what the target and features need
* the build counts of cargo2nix and crate2nix include `trunk` itself
* cargo2nix uses its own `Cargo.lock` here (512 crates.io packages), so its numbers are not directly comparable with the others
* crate2nix via `tools.nix` also fetches all 471 crates at evaluation time to generate `Cargo.nix`. these `crates-io-*` paths don't show up in the closure of the result
* the custom registry row comes from reading the locked sources, it was not tested against a real registry
* the crane and naersk flakes here use `fetchFromGitHub` as `src`, so they need IFD as they are. with `builtins.fetchTarball` as `src` both evaluate with `--option allow-import-from-derivation false`
* crane's `registryFromGitIndex` needs IFD by its docs. `registryFromDownloadUrl` doesn't, and `registryFromSparse` reads `config.json` with `builtins.fetchurl`, which is not IFD
* `tools.nix` from crate2nix throws `unknown source type` for anything other than crates.io and git, so custom registries don't work via IFD
* in the crane, naersk and crate2nix flakes the rust-overlay/fenix toolchain is only used by the devShell. the package itself gets rustc from nixpkgs-24.11
* cargo2nix gets the nixpkgs rustc and cargo via `rustToolchain`. the official 1.82.0 binary from rust-overlay is a lot faster, see below, and using it for only one tool makes the comparison meaningless. the flake also sets `CARGO_NET_OFFLINE` for every crate, because cargo 1.82 re-resolves the single crate manifest cargo2nix generates and then asks for the crates.io index (`Could not resolve host: index.crates.io`). cargo 1.86 does not do that

# more metrics

these ran in throwaway copies of the flakes with the same `flake.lock` files, the flakes in this repo are not changed by them. the cargo2nix tests and the sharing fixture ran with rustc 1.86.0 and were not repeated. the first table and the tests are measured, cross compilation and git dependencies come from reading the locked sources.

## rebuild cost

derivations rebuilt and seconds of `nix build` after the first build. `edit` adds a comment to `trunk`'s `src/main.rs`, `bump` updates only `log` in `Cargo.lock` (cargo2nix: 0.4.27 to 0.4.28, the others: 0.4.22 to 0.4.26). crane's tests are off so that it matches the others. crane and naersk recompile about 360 crates inside `trunk-deps`, which these derivation counts hide.

| | crane | naersk | cargo2nix | crate2nix |
|---|---|---|---|---|
| edit, nixpkgs rustc | 1, 291s | 1, 294s | 1, 288s | 1, 165s (no LTO) |
| bump, nixpkgs rustc | 7, 488s | 8, 403s | 37, 384s | 39, 289s (no LTO) |
| edit, official rustc | 1, 169s | 1, 155s | 1, 179s | not measured |
| bump, official rustc | 2, 286s | 2, 232s | 37, 236s | not measured |

* these are single runs on one machine, so differences of about 10% mean little. cargo2nix uses a different lock. earlier runs gave crane 265s and 448s, naersk 266s and 393s, crate2nix 149s and 271s
* the derivation count of a bump includes fetching and vendoring, for crane and naersk that is everything except `trunk-deps` and `trunk`
* per crate builds rebuild only what depends on the change: the rebuilt crates of a bump are exactly the reverse dependencies of `log`, 37 of 384 with cargo2nix and 38 of 358 with crate2nix (`h2`, `hyper`, `reqwest`, `tracing`, `lightningcss`, `oxipng`, ...). crane and naersk rebuild all dependencies in `trunk-deps`
* the official rustc is the same version from the same commit as the nixpkgs one, but about 1.6 to 1.9 times faster. it was swapped in throwaway copies of the flakes: `overrideToolchain` for crane, `cargo` and `rustc` arguments for naersk, `rustVersion = "1.82.0"` for cargo2nix. `pkgs/development/compilers/rust/rustc.nix` sets no LTO, PGO or BOLT and links a shared LLVM
* per crate builds saved no time: with the official rustc naersk needs 232s and cargo2nix 236s. cargo compiles all dependencies in 74s, the 37 derivations of cargo2nix take about 60s. crane needs 120s because `buildDepsOnly` runs `cargo check` and `cargo build`
* `lightningcss` took 49s with cargo2nix and the official rustc, 70s with cargo2nix and the nixpkgs rustc, and 112s with crate2nix. the compiler explains the first gap, the reason for the second is unknown
* compiling `trunk` itself is the biggest part of every rebuild, per crate builds can't help there
* crate2nix ignores `lto = "fat"` and `panic = "abort"` from `trunk`'s `[profile.release]`: `buildRustCrate` from nixpkgs has no support for them, its rustc call only sets `opt-level` and `codegen-units`. so its `trunk` is a different build, 33.9 MB compared to 29.5 MB with crane

## the other metrics

| | crane | naersk | cargo2nix | crate2nix |
|---|---|---|---|---|
| builds `trunk` with cargo's features | yes, runs `cargo` | yes, runs `cargo` | yes, no fixes needed | one crate override needed |
| default toolchain | nixpkgs | nixpkgs | required in `makePackageSet` | nixpkgs |
| change the toolchain | `overrideToolchain` | `cargo` and `rustc` arguments | `rustVersion`, `rustChannel`, `rustToolchain` | nixpkgs overlay for `rustc` |
| tests by default | run | off | off | off |
| `trunk` tests when enabled | 77 passed, 1 skipped | 77 passed, 1 skipped | don't compile | 77 passed, 1 skipped |
| stale generated file | nothing generated | nothing generated | stops with `out of sync` | silently builds the old version |
| cross examples shipped | musl, windows, rust-overlay | windows, static musl, multi target | `3-cross-compiling` | sample projects only |
| git dependencies | from `Cargo.lock`, `outputHashes` optional | from `Cargo.lock` | from `Cargo.lock`, not with `restrict-eval` | hash needed in `crate-hashes.json` |
| compiled crates shared between projects | no | no | yes, if features match | yes, if features match |

notes:

* **features**: of the 358 crates crate2nix compiles, no cargo feature is missing. 20 crates get extra features which cargo doesn't set, nearly all of them named after optional dependencies, the same cause as the `lightningcss` failure. only `lightningcss` breaks. it also passes `feature="default"` to every crate
* **tests**: `doCheck` in naersk needs a test command which passes `--skip` after `--`. `cargo_test_options` in `naersk/flake.nix` fails with `unexpected argument '--skip'` when tests are enabled, which goes unnoticed because they are off
* **cargo2nix tests**: `rstest` fails with `Could not find rstest in dependencies or dev-dependencies` when `compileMode = "test"` compiles `trunk`
* **stale files**: with `log` at 0.4.25 in `Cargo.lock` and the old `Cargo.nix`, crate2nix still compiles `rust_log-0.4.22`. with `tools.nix` this can't happen, `Cargo.nix` is regenerated
* **regenerating with cargo2nix**: use `cargo2nix -f Cargo.nix -o -l`, on the unchanged lock this reproduces the committed `Cargo.nix` exactly. without `-l` it updates `Cargo.lock`, and its embedded cargo 0.73 can't read edition 2024 crates or lock file version 4
* **sharing**: a small project using `itoa`, `log` and `serde` in the versions from `trunk`'s lock shares 1 of 3 compiled crates with `trunk` for both cargo2nix and crate2nix. only `itoa` matches, `log` and `serde` differ in features. crane and naersk build all dependencies of a project into one derivation, so only downloads can be shared

# crate2nix and trunk

`trunk` failed in `lightningcss` with errors like:

```
error[E0277]: the trait bound `SmallVec<[...; 1]>: Serialize` is not satisfied
error[E0599]: no method named `into_owned` found for struct `MediaQuery`
```

`lightningcss` has the default feature `nodejs = [ "dep:serde" ]`. crate2nix's `enableFeatures` turns an enabled optional dependency into a feature of the same name, so rustc gets `--cfg feature="serde"`. cargo does not do that:

```
lightningcss v1.0.0-alpha.60 [bundler,dashmap,default,grid,nodejs,parcel_sourcemap,rayon,sourcemap]
```

so the `serde` code is compiled but `smallvec/serde`, `parcel_selectors/serde` and `into_owned` are missing. `crate2nix/flake.nix` removes that feature in a crate override.

the flake uses the IFD route, `appliedCargoNix`. to use the committed `Cargo.nix` instead, switch to the commented out `pkgs.callPackage ./Cargo.nix {}` and also remove the `rust` and `cargo` lines from the overlay, because `Cargo.nix` needs `pkgs.rust.lib` (`attribute 'lib' missing`). that combination builds with `--option allow-import-from-derivation false`.

# reproduce

```bash
cd crate2nix
nix build --no-update-lock-file .#default
./result/bin/trunk --version
nix path-info --derivation --recursive .#default | grep -c '^/nix/store/[a-z0-9]*-rust_'
nix eval --raw --option allow-import-from-derivation false .#default.drvPath
```

the last command fails for crane, naersk and crate2nix as they are in this repo, and works for cargo2nix.
