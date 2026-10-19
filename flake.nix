{
  description = "Simple Julia Project";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
    flake-parts.url = "github:hercules-ci/flake-parts";
    manifest2nix.url = "git+https://codeberg.org/aniva/Manifest2Nix.jl.git";
  };

  outputs =
    inputs@{
      nixpkgs,
      flake-parts,
      manifest2nix,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      perSystem =
        { system, ... }:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
          # JETLS recommends 1.12.2+, pkgs.julia is 1.12.1, julia-bin 1.12.5 :)
          julia = pkgs.julia-bin;
          m2nlib = manifest2nix.mkLib pkgs;
          jetls_rev = "2026-02-27";
          jetls_src = pkgs.fetchFromGitHub {
            owner = "aviatesk";
            repo = "JETLS.jl";
            tag = jetls_rev;
            hash = "";
          };
          # simply jetls-src with the generated manifest.
          with_manifest = pkgs.runCommand "build" { } ''
            mkdir $out
            cp -r ${jetls_src}/* $out/
            cp ${./Manifest.toml} $out/Manifest.toml
          '';
          package = m2nlib.buildJuliaPackageWithDeps {
            src = with_manifest;
            lockFile = ./Lock.toml;
          };
          jetls_env = m2nlib.createEnv { package = package; };
        in
        {
          packages = rec {
            inherit julia;
            default = jetls;
            # mostly nicked from the default Pkg.App setup from julia.
            jetls = pkgs.writeShellScriptBin "jetls" ''
              export JULIA_LOAD_PATH="${jetls_env.JULIA_LOAD_PATH}:"
              export JULIA_DEPOT_PATH="$HOME/.julia:${jetls_env.JULIA_DEPOT_PATH}:${m2nlib.stdlibDepot}"

              export julia_cmd="${julia}/bin/julia"
              found_separator=false
              for a in "$@"; do
                  [ "$a" = "--" ] && { found_separator=true; break; }
              done

              julia_args=""
              if [ "$found_separator" = "true" ]; then
                  # Build julia_args until `--`, then leave the rest in "$@"
                  while [ "$#" -gt 0 ]; do
                      case "$1" in
                      --) shift; break ;;
                      *)  julia_args="$julia_args''${julia_args:+ }$1"; shift ;;
                      esac
                  done
                  # Here: "$@" are the app args after the separator
              fi
              exec "$julia_cmd" --startup-file=no --startup-file=no --history-file=no --threads=auto $julia_args -m JETLS "$@"
            '';
            update_manifest = pkgs.writeShellScriptBin "update_manifest" ''
              echo ${jetls_src}
              export JULIA_DEPOT_PATH="./.julia"
              # I'd love to use jetls_src here, but it'll be installed by another
              # user, which git (used by Pkg) cannot deal with :(
              ${julia}/bin/julia -e 'using Pkg; Pkg.Apps.add(; url="https://github.com/aviatesk/JETLS.jl", rev="${jetls_rev}")'
              cp $JULIA_DEPOT_PATH/environments/apps/JETLS/Manifest.toml .
            '';
            # needs to be a separate step because with_manifest is not up-to-date when update_manifest is called.
            update_lock = pkgs.writeShellScriptBin "update_lock" ''
              ${
                manifest2nix.packages.${system}.manifest2nix
              }/bin/manifest2nix lock --project ${with_manifest} -o ./Lock.toml
            '';
          };
        };
    };
}
