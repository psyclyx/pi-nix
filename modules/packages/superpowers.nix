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
  cfg = config.pi.packages.superpowers;
  entry = packageLib.registryEntry registry "superpowers";
  source = packageLib.npmPackageSource {
    inherit pkgs entry;
  };
in
{
  options.pi.packages.superpowers =
    packageLib.packageResourceOptions {
      defaultSource = source;
      description = "Official Superpowers workflow skills for Pi";
    }
    // {
      enableRecommendedCompanions = lib.mkOption {
        type = types.bool;
        default = true;
        description = "Enable Pi subagents and todo companions with mkDefault for fuller Superpowers workflows.";
      };
      disableTelemetry = lib.mkOption {
        type = types.bool;
        default = true;
        description = "Disable optional Superpowers visual companion telemetry.";
      };
      environment = lib.mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Raw Superpowers environment overrides.";
      };
    };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf cfg.enableRecommendedCompanions {
        pi.packages.subagents.enable = lib.mkDefault true;
        pi.packages.todo.enable = lib.mkDefault true;
      })
      {
        pi.packageEntries = [ (packageLib.packageEntry cfg) ];
        pi.environment =
          lib.optionalAttrs cfg.disableTelemetry {
            SUPERPOWERS_DISABLE_TELEMETRY = "1";
          }
          // cfg.environment;
      }
    ]
  );
}
