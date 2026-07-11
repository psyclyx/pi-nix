{
  config,
  lib,
  pkgs,
  registry ? { },
  ...
}:

let
  packageLib = import ./lib.nix { inherit lib; };
  inherit (lib) types;

  packageModule =
    { name, ... }:
    {
      options =
        packageLib.packageResourceOptions {
          defaultSource = packageLib.packageSource {
            inherit pkgs registry;
            entry = packageLib.registryEntry registry name;
            piPackage = config.pi.package;
          };
          description = "Curated Pi package \"${name}\" resolved from the pinned registry";
        }
        // packageLib.packageConfigOptions
        // {
          order = lib.mkOption {
            type = types.int;
            default = 1000;
            description = "Ordering of this package entry within settings.json packages.";
          };
        };
    };

  packageItems = lib.mapAttrsToList (
    name: cfg: {
      inherit name cfg;
    }
  ) config.pi.packages.registry;
  enabled = lib.filter (item: item.cfg.enable) packageItems;
  orderedEnabled = lib.sort (a: b: a.cfg.order < b.cfg.order) enabled;
in
{
  options.pi.packages.registry = lib.mkOption {
    type = types.attrsOf (types.submodule packageModule);
    default = { };
    description = ''
      Curated Pi packages resolved by name from the pinned registry, built as
      Nix-managed offline sources. The attribute name is the registry entry name
      (e.g. superpowers, pi-ask-user, add-dir).
    '';
  };

  config = {
    pi.packageEntries = map (item: packageLib.packageEntry item.cfg) orderedEnabled;
    pi.settings = lib.mkMerge (map (item: item.cfg.settings) orderedEnabled);
    pi.files = lib.mkMerge (map (item: item.cfg.files) orderedEnabled);
    pi.environment = lib.mkMerge (map (item: item.cfg.environment) orderedEnabled);
  };
}
