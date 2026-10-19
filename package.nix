{
  lib,
  julia,
  fetchFromGitHub,
  writeShellApplication,
  runCommand,
  python3,
}:
let
  src = fetchFromGitHub {
    owner = "aviatesk";
    repo = "JETLS.jl";
    tag = "2026-10-18";
    hash = "sha256-rIoHnoIdcEwa4OMLRsrnXcXJKHaI8O1bMOj7A8JD1D8=";
  };
  project = builtins.fromTOML (builtins.readFile "${src}/Project.toml");

  # Follow the release's [sources], including its vendored, unregistered packages.
  # Fetching the source revision separately matters: it need not equal the tag.
  sourceHashes = {
    "28f9ade325674d450eced8588572ce570218705c" = "sha256-O8a1aGE++PtBa967e5SosmOpDU7XF0Y9Aq70+FdplhI=";
  };
  packageOverrides =
    lib.mapAttrs (
      _: source:
      let
        repo = fetchFromGitHub {
          owner = "aviatesk";
          repo = "JETLS.jl";
          inherit (source) rev;
          hash = sourceHashes.${source.rev};
        };
      in
      assert source.url == "https://github.com/aviatesk/JETLS.jl";
      "${repo}/${source.subdir}"
    ) project.sources
    // {
      JETLS = src;
    };

  resolved =
    (julia.withPackages.override {
      inherit julia packageOverrides;
      setDefaultDepot = false;
      juliaCpuTarget = "generic";
    })
      (builtins.attrNames packageOverrides);

  # Nixpkgs' project.py emits only uuid/path for unregistered overrides,
  # omitting their dependencies. Repair that metadata before instantiation.
  fixedProject =
    runCommand "jetls-project-${julia.version}"
      {
        nativeBuildInputs = [ (python3.withPackages (ps: [ ps.toml ])) ];
      }
      ''
        mkdir -p $out
        cp ${resolved.project}/*.toml $out/
        chmod u+w $out/*.toml
        python ${./fix-manifest.py} $out
      '';
  environment = resolved.projectAndDepot.overrideAttrs { project = fixedProject; };
in
assert lib.assertMsg (
  lib.versionAtLeast julia.version "1.12.2" && lib.versionOlder julia.version "1.14"
) "JETLS ${project.version} requires Julia ${project.compat.julia}; got ${julia.version}";
writeShellApplication {
  name = "jetls";
  text = ''
    # Do not inherit the editor's Julia project, load path or personal depot.
    export JULIA_PROJECT=${environment}/project
    export JULIA_LOAD_PATH="@:@stdlib"
    export JULIA_DEPOT_PATH=${environment}/depot
    export JULIA_CPU_TARGET=generic
    export JULIA_PKG_OFFLINE=true
    exec ${resolved.juliaWrapped}/bin/julia --startup-file=no --history-file=no --threads=auto -m JETLS "$@"
  '';
  passthru = {
    inherit
      julia
      src
      project
      environment
      ;
    version = project.version;
  };
  meta = {
    description = "Julia language server (JETLS), using Julia ${julia.version}";
    homepage = "https://github.com/aviatesk/JETLS.jl";
    license = lib.licenses.mit;
    mainProgram = "jetls";
    platforms = julia.meta.platforms;
  };
}
