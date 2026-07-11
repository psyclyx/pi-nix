{ config, lib, ... }:

let
  packageLib = import ./lib.nix { inherit lib; };
  inherit (lib) types;

  packageModule =
    { name, ... }:
    {
      options = {
        enable = lib.mkOption {
          type = types.bool;
          default = true;
          description = "Whether to include the custom Pi package ${name}.";
        };

        source = lib.mkOption {
          type = packageLib.sourceType;
          example = "git:github.com/user/pi-package@v1";
          description = ''
            Pi package source. Use npm:<package>@<version>, git:<host>/<owner>/<repo>@<ref>,
            a protocol URL, an absolute path, or a relative path understood by Pi.
          '';
        };

        developmentPath = packageLib.nullable packageLib.sourceType // {
          description = "Local package path to use instead of source while iterating.";
        };

        autoload = packageLib.nullable types.bool // {
          description = "Pi package autoload override.";
        };

        extensions = packageLib.nullable (types.listOf types.str) // {
          description = "Extension filters. Null loads package defaults; [] loads none.";
        };

        skills = packageLib.nullable (types.listOf types.str) // {
          description = "Skill filters. Null loads package defaults; [] loads none.";
        };

        prompts = packageLib.nullable (types.listOf types.str) // {
          description = "Prompt filters. Null loads package defaults; [] loads none.";
        };

        themes = packageLib.nullable (types.listOf types.str) // {
          description = "Theme filters. Null loads package defaults; [] loads none.";
        };
      }
      // packageLib.packageConfigOptions;
    };

  packageItems = lib.mapAttrsToList (
    name: cfg: {
      inherit name cfg;
    }
  ) config.pi.packages.custom;
  enabled = lib.filter (item: item.cfg.enable) packageItems;
in
{
  options.pi.packages.custom = lib.mkOption {
    type = types.attrsOf (types.submodule packageModule);
    default = { };
    description = "Named custom Pi packages loaded through normal settings.json package entries.";
  };

  config = {
    pi.packageEntries = map (item: packageLib.packageEntry item.cfg) enabled;
    pi.settings = lib.mkMerge (map (item: item.cfg.settings) enabled);
    pi.files = lib.mkMerge (map (item: item.cfg.files) enabled);
    pi.environment = lib.mkMerge (map (item: item.cfg.environment) enabled);
  };
}
