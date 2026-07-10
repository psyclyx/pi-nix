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
in
{
  options.pi.packages.btw = packageLib.packageResourceOptions {
    defaultSource = packageLib.packageSource {
      inherit pkgs registry entry;
      piPackage = config.pi.package;
    };
    description = "/btw side-question command for Pi";
  };

  config = lib.mkIf cfg.enable {
    pi.packageEntries = lib.mkOrder 360 [ (packageLib.packageEntry cfg) ];
  };
}
