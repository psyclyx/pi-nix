{
  config,
  lib,
  pkgs,
  registry ? { },
  ...
}:

let
  packageLib = import ./lib.nix { inherit lib; };
  cfg = config.pi.packages.goal;
  entry = packageLib.registryEntry registry "goal";
  source = packageLib.npmPackageSource { inherit pkgs entry; };
in
{
  options.pi.packages.goal = packageLib.packageResourceOptions {
    defaultSource = source;
    description = "Persistent /goal command for Pi";
  };

  config = lib.mkIf cfg.enable {
    pi.packageEntries = [ (packageLib.packageEntry cfg) ];
  };
}
