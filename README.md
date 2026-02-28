This repo packages JETLS, a language server for julia, for nix via
[`manifest2nix`](https://codeberg.org/aniva/Manifest2Nix.jl).
Since jetls does not provide the required `Manifest.toml`, it is provided in
this repo, and can be updated by changing `jetls_rev` in `flake.nix`, and
running
```bash
nix run .#update-manifest
nix run .#update-lock
```
