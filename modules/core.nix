{ config, lib, ... }:

let
  inherit (lib) types;
in
{
  options.pi = {
    enable = lib.mkEnableOption "Pi coding agent configuration";

    package = lib.mkOption {
      type = types.nullOr types.package;
      default = null;
      description = "The Pi agent package to expose when one is available.";
    };

    settings = lib.mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Configuration data emitted as settings.json by piConfiguration.";
    };

    packageEntries = lib.mkOption {
      type = types.listOf types.anything;
      default = [ ];
      internal = true;
      description = "Package entries merged into Pi settings.json packages.";
    };

    files = lib.mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "JSON config files written relative to PI_CODING_AGENT_DIR by the generated launcher.";
    };

    extraPackages = lib.mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.git pkgs.ripgrep pkgs.fd pkgs.jq ]";
      description = "Extra tools expected to be available to the agent.";
    };

    environment = lib.mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = lib.literalExpression ''{ PI_MODEL = "pi"; }'';
      description = "Environment variables for launching the agent.";
    };

    agentDirEnvironment = lib.mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = lib.literalExpression ''{ PI_LENS_CONFIG_PATH = "config/pi-lens/config.json"; }'';
      description = "Environment variables whose values are paths relative to PI_CODING_AGENT_DIR.";
    };
  };

  config.pi.settings = lib.optionalAttrs (config.pi.packageEntries != [ ]) {
    packages = config.pi.packageEntries;
  };
}
