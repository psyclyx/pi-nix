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

    environmentFiles = lib.mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = lib.literalExpression ''{ OPENAI_API_KEY = "/run/secrets/openai-api-key"; }'';
      description = ''
        Environment variables whose values are read from runtime files by the
        generated launcher. This keeps secrets out of the Nix store and
        generated settings files.
      '';
    };

    agentDirEnvironment = lib.mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = lib.literalExpression ''{ EXAMPLE_CONFIG_PATH = "config/example.json"; }'';
      description = "Environment variables whose values are paths relative to PI_CODING_AGENT_DIR.";
    };

    telemetry.enable = lib.mkOption {
      type = types.bool;
      default = false;
      description = ''
        Master switch for Pi's telemetry and analytics. Disabled by default.
        Drives PI_TELEMETRY (runtime telemetry), enableInstallTelemetry
        (install/update telemetry), and enableAnalytics (usage analytics).
        Individual plugins with their own telemetry (e.g. superpowers) are
        controlled through their package environment.
      '';
    };
  };

  config = {
    pi.settings = lib.mkMerge [
      (lib.optionalAttrs (config.pi.packageEntries != [ ]) {
        packages = config.pi.packageEntries;
      })
      {
        enableInstallTelemetry = lib.mkDefault config.pi.telemetry.enable;
        enableAnalytics = lib.mkDefault config.pi.telemetry.enable;
      }
    ];

    pi.environment = lib.mkMerge [
      { PI_TELEMETRY = lib.mkDefault (if config.pi.telemetry.enable then "1" else "0"); }
      # When telemetry is off, also emit the broad cross-tool opt-out signals that
      # plugins honor (e.g. superpowers checks both), so plugin-level telemetry is
      # covered by the master switch without per-package configuration.
      (lib.optionalAttrs (!config.pi.telemetry.enable) {
        DISABLE_TELEMETRY = lib.mkDefault "1";
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = lib.mkDefault "1";
      })
    ];
  };
}
