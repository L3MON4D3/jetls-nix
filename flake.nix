{
  description = "JETLS, parameterized by the Julia package";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ nixpkgs, flake-parts, ... }:
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
          pkgs = import nixpkgs { inherit system; };
          jetls = pkgs.callPackage ./package.nix { julia = pkgs.julia-bin; };
        in
        {
          packages = {
            inherit jetls;
            default = jetls;
          };
        };
    };
}
