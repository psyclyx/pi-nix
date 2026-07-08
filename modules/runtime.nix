{
  config,
  lib,
  piPackages ? { },
  ...
}:

let
  inherit (lib) types;
  cfg = config.pi.runtime;
in
{
  options.pi.runtime = {
    launcherName = lib.mkOption {
      type = types.str;
      default = "pi-nix";
      description = "Name of the generated Pi wrapper command.";
    };

    stateDir = lib.mkOption {
      type = types.str;
      default = "\${XDG_STATE_HOME:-$HOME/.local/state}/pi-nix/agent";
      description = "Mutable runtime directory used as PI_CODING_AGENT_DIR by the wrapper.";
    };

    packageDir = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Pi package root used as PI_PACKAGE_DIR by the wrapper. Null points at
        the packaged Pi node module in the Nix store. Override this only when
        testing a different Pi package tree.
      '';
    };

    auth = {
      mode = lib.mkOption {
        type = types.enum [
          "existing"
          "directory"
          "isolated"
        ];
        default = "existing";
        description = ''
          How the wrapper handles auth.json. "existing" links only auth.json from
          ~/.pi/agent, "directory" links auth.json from auth.directory, and
          "isolated" keeps auth inside the generated runtime directory.
        '';
      };

      directory = lib.mkOption {
        type = types.str;
        default = "$HOME/.pi/agent";
        description = "Directory containing auth.json when auth.mode is directory.";
      };
    };

    projectTrust = lib.mkOption {
      type = types.nullOr (
        types.enum [
          "approve"
          "no-approve"
        ]
      );
      default = null;
      description = "Optional one-run project trust override. Null leaves Pi's CLI default unchanged.";
    };

    projectConfig = lib.mkOption {
      type = types.nullOr (
        types.enum [
          "ask"
          "always"
          "never"
        ]
      );
      default = "ask";
      description = ''
        How Pi handles project-local .pi/settings.json and .pi resources by default.
        "ask" keeps Pi's interactive trust prompt, "always" reads trusted project
        config without prompting, and "never" ignores project config unless the
        command line explicitly overrides trust. Set null to omit this setting.
      '';
    };

    contextFiles = lib.mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Optional context-file CLI override. False passes --no-context-files; null leaves Pi's default unchanged.";
    };

    offline = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Set PI_OFFLINE=1 for the wrapper.";
    };

    skipVersionCheck = lib.mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Set PI_SKIP_VERSION_CHECK when non-null.";
    };

    telemetry = lib.mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Set PI_TELEMETRY when non-null.";
    };

    installTelemetry = lib.mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Whether generated settings should allow Pi install/update telemetry. Null omits the setting.";
    };

    extraArgs = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra CLI arguments prepended by the generated wrapper.";
    };
  };

  config = {
    pi.package = lib.mkDefault (piPackages.pi or null);

    pi.environment =
      lib.optionalAttrs (cfg.telemetry != null) {
        PI_TELEMETRY = if cfg.telemetry then "1" else "0";
      }
      // lib.optionalAttrs (cfg.skipVersionCheck != null) {
        PI_SKIP_VERSION_CHECK = if cfg.skipVersionCheck then "1" else "0";
      }
      // lib.optionalAttrs cfg.offline {
        PI_OFFLINE = "1";
      };

    pi.settings = lib.optionalAttrs (cfg.installTelemetry != null) {
      enableInstallTelemetry = lib.mkDefault cfg.installTelemetry;
    };

    pi.core.defaultProjectTrust = lib.mkIf (cfg.projectConfig != null) (
      lib.mkDefault cfg.projectConfig
    );
  };
}
