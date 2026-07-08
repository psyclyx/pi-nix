{
  buildNpmPackage,
  fetchzip,
  importNpmLock,
  lib,
  entry ? { },
}:

let
  required =
    field:
    if builtins.hasAttr field entry then
      builtins.getAttr field entry
    else
      throw "pi-nix: registry.packages.pi.${field} is required";

  version = required "version";
  tarball = required "tarball";
  sourceHash = required "unpackHash";
  npmLockIntegrities = entry.npmLockIntegrities or { };
  src = fetchzip {
    url = tarball;
    hash = sourceHash;
  };
  packageJson = builtins.removeAttrs (lib.importJSON "${src}/package.json") [
    "devDependencies"
    "scripts"
  ];

  originalLock = lib.importJSON "${src}/npm-shrinkwrap.json";
  patchedLock = originalLock // {
    packages = lib.mapAttrs (
      lockPath: package:
      package
      // lib.optionalAttrs (builtins.hasAttr lockPath npmLockIntegrities && !(package ? integrity)) {
        integrity = builtins.getAttr lockPath npmLockIntegrities;
      }
    ) originalLock.packages;
  };
in
buildNpmPackage {
  pname = "pi";
  inherit version src;

  dontNpmBuild = true;
  dontNpmPrune = true;
  npmInstallFlags = [ "--omit=dev" ];
  npmDeps = importNpmLock {
    npmRoot = src;
    package = packageJson;
    packageLock = patchedLock;
  };
  npmConfigHook = importNpmLock.npmConfigHook;

  postPatch = ''
    rm -f npm-shrinkwrap.json
  '';

  passthru = {
    inherit entry;
  };

  meta = {
    description = "Pi coding agent packaged by pi-nix";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "pi";
  };
}
