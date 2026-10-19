# JETLS for Nix

JETLS and its dependencies are resolved and precompiled **for the supplied Julia
package**, using `julia.withPackages`. No checked-in Julia manifest or
Manifest2Nix lock is used. Sources, project, depot, and precompiled caches live in
the Nix store; the launcher does not use or create `~/.julia`.

```sh
nix build .#jetls
nix run .#jetls -- --version
nix run .#jetls -- serve               # stdio LSP (editor command)
nix flake check                       # CLI, diagnostics, and stdio LSP smoke test
```

For new, untracked files, use `path:.` instead of `.` (or `git add` them first),
so Nix includes them in the flake source.

## Choose Julia

The package is a normal `callPackage` function:

```nix
pkgs.callPackage ./package.nix { julia = pkgs.julia_112-bin; }
```

To keep this flake's pinned nixpkgs for dependency resolution and building while
using your own Julia interpreter, override the exported package:

```nix
jetls = inputs.jetls-nix.packages.${system}.jetls.override {
  julia = myJulia;
};
```

The `withPackages` builder defaults to the one from the package set used to call
`package.nix`, not the one attached to `myJulia`. The interpreter only needs to
provide a working `bin/julia`, `version`, and `meta.platforms`; it does not need
its own `withPackages` attribute. You can explicitly override the builder with
`juliaWithPackages` if needed. For cache sharing, the supplied interpreter must
still have the same store path.

The default uses `julia-bin`. JETLS release `2026-10-18` supports Julia
**1.12.2 through 1.13.x** (as specified by its release `Project.toml`). An
unsupported Julia version fails explicitly, rather than reusing an incompatible
manifest. Changing Julia rebuilds the resolution, depot and precompilation. This
does not make upstream JETLS compatible with Julia versions it does not support.

## Packaging details

The release's `[sources]` entries determine `packageOverrides`, including the
unregistered vendored dependencies. These revisions are fetched separately from
the release tag, with fixed Nix hashes. `fix-manifest.py` repairs a nixpkgs
`withPackages` bug: unregistered overrides otherwise lose their dependency and
extension metadata in the generated manifest. It does not re-resolve packages.

The launcher ignores inherited `JULIA_PROJECT`, `JULIA_LOAD_PATH` and
`JULIA_DEPOT_PATH`, disables startup/history files, and uses generic-CPU
precompilation. It neither installs packages nor downloads dependencies at
startup. Editor projects must have their own dependencies provisioned separately;
this package does not instantiate them or consult a personal Julia depot.

`withPackages` uses import-from-derivation, so evaluation can build Julia and
resolve dependencies. Native builds are required; the advertised Darwin/aarch64
systems are not cross-compilation targets.

To update JETLS, change the release tag/hash in `package.nix`, update
`sourceHashes` for the release's `[sources]` revisions, review its Julia
compatibility bounds and the smoke test's expected release, and run the checks.
See the upstream
[release project](https://github.com/aviatesk/JETLS.jl/blob/2026-10-18/Project.toml)
and [nixpkgs Julia documentation](https://github.com/NixOS/nixpkgs/blob/2fc6539b481e1d2569f25f8799236694180c0993/doc/languages-frameworks/julia.section.md).
