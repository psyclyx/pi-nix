{
  config,
  lib,
  pkgs,
  registry ? { },
  ...
}:

let
  packageLib = import ./lib.nix { inherit lib; };
  cfg = config.pi.packages.btw;
  entry = packageLib.registryEntry registry "btw";
  source = packageLib.npmPackageSource { inherit pkgs entry; };
in
{
  options.pi.packages.btw = packageLib.packageResourceOptions {
    defaultSource = source;
    description = "/btw side-question command for Pi";
  };

  config = lib.mkIf cfg.enable {
    pi.packageEntries = [ (packageLib.packageEntry cfg) ];
  };
}
