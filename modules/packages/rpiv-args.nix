{
  config,
  lib,
  pkgs,
  registry ? { },
  ...
}:

let
  packageLib = import ./lib.nix { inherit lib; };
  cfg = config.pi.packages.rpivArgs;
  entry = packageLib.registryEntry registry "rpiv-args";
  source = packageLib.npmPackageSource { inherit pkgs entry; };
in
{
  options.pi.packages.rpivArgs = packageLib.packageResourceOptions {
    defaultSource = source;
    description = "RPiV skill argument and shell substitution support";
  };

  config = lib.mkIf cfg.enable {
    pi.packageEntries = [ (packageLib.packageEntry cfg) ];
  };
}
