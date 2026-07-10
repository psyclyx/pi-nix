{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) types;
  piNix = import ../default.nix { inherit pkgs; };
  cfg = config.programs.pi-nix;

  profileModule =
    { name, config, ... }:
    {
      options = {
        enable = lib.mkOption {
          type = types.bool;
          default = true;
          description = "Whether to install this Pi profile.";
        };

        binaryName = lib.mkOption {
          type = types.str;
          default = name;
          description = "Command name for this generated Pi profile.";
        };

        package = lib.mkOption {
          type = types.package;
          default = piNix.packages.pi.override {
            inherit (config) binaryName;
          };
          defaultText = lib.literalExpression "piNix.packages.pi.override { binaryName = config.binaryName; }";
          description = "Pi package used by this profile.";
        };

        modules = lib.mkOption {
          type = types.listOf types.deferredModule;
          default = [ ];
          description = "pi-nix modules used to build this profile.";
        };

        specialArgs = lib.mkOption {
          type = types.attrsOf types.anything;
          default = { };
          description = "Additional specialArgs passed to piConfiguration.";
        };
      };
    };

  enabledProfiles = lib.filterAttrs (_: profile: profile.enable) cfg.profiles;
  profileConfigurations = lib.mapAttrs (
    _: profile:
    piNix.piConfiguration {
      inherit (profile) specialArgs;
      modules = [
        (
          { lib, ... }:
          {
            pi.package = lib.mkOverride 900 profile.package;
            pi.runtime.launcherName = lib.mkDefault profile.binaryName;
          }
        )
      ]
      ++ profile.modules;
    }
  ) enabledProfiles;
in
{
  options.programs.pi-nix = {
    enable = lib.mkEnableOption "pi-nix managed Pi profiles";

    profiles = lib.mkOption {
      type = types.attrsOf (types.submodule profileModule);
      default = { };
      description = "Named Pi profiles. Each profile builds an independent command.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.pi-nix.profiles.pi = lib.mkDefault {
      binaryName = "pi";
      modules = [ ../examples/daily-driver.nix ];
    };

    home.packages = lib.unique (
      lib.flatten (
        lib.mapAttrsToList (
          name: profile:
          let
            profileConfiguration = profileConfigurations.${name};
          in
          profileConfiguration.extraPackages
          ++ lib.optional (profileConfiguration.launcher != null) profileConfiguration.launcher
        ) enabledProfiles
      )
    );
  };
}
