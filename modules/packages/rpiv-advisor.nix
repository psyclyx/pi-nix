{
  config,
  lib,
  piPackages ? { },
  pkgs,
  registry ? { },
  ...
}:

let
  packageLib = import ./lib.nix { inherit lib; };
  inherit (lib) types;
  cfg = config.pi.packages.rpivAdvisor;
  entry = packageLib.registryEntry registry "rpiv-advisor";
  piPeer = packageLib.piPackageNodeModule (piPackages.pi or config.pi.package);
  typebox = piPeer "typebox";
  rpivConfig = packageLib.npmPackageSource {
    inherit pkgs;
    entry = packageLib.npmRegistryEntry registry "rpiv-config";
    nodeModules = {
      inherit typebox;
    };
  };
  source = packageLib.npmPackageSource {
    inherit pkgs entry;
    nodeModules = {
      inherit typebox;
      "@juicesharp/rpiv-config" = rpivConfig;
    };
    patches = ''
      substituteInPlace "$out/advisor/config.ts" \
        --replace-fail 'const ADVISOR_CONFIG_PATH = configPath("rpiv-advisor", "advisor.json");' \
        'const ADVISOR_CONFIG_PATH = process.env.RPIV_ADVISOR_CONFIG_PATH?.trim() || configPath("rpiv-advisor", "advisor.json");'
    '';
  };
  disabledEntryType = types.either types.str (
    types.submodule {
      options = {
        model = lib.mkOption {
          type = types.str;
          description = "Executor model key.";
        };
        minEffort =
          packageLib.nullable (
            types.enum [
              "minimal"
              "low"
              "medium"
              "high"
              "xhigh"
            ]
          )
          // {
            description = "Minimum executor effort where advisor is disabled.";
          };
      };
    }
  );
  advisorConfig =
    packageLib.clean {
      inherit (cfg)
        modelKey
        effort
        disabledForModels
        ;
      guidance = packageLib.clean cfg.guidance;
    }
    // cfg.extraConfig;
in
{
  options.pi.packages.rpivAdvisor =
    packageLib.packageResourceOptions {
      defaultSource = source;
      description = "RPiV advisor second-opinion tool";
    }
    // {
      modelKey = packageLib.nullable types.str // {
        description = "Advisor model key, using the upstream provider:id codec.";
      };
      effort =
        packageLib.nullable (
          types.enum [
            "minimal"
            "low"
            "medium"
            "high"
            "xhigh"
          ]
        )
        // {
          description = "Advisor thinking effort.";
        };
      guidance = {
        promptSnippet = packageLib.nullable types.str // {
          description = "guidance.promptSnippet.";
        };
        promptGuidelines = packageLib.nullable (types.listOf types.str) // {
          description = "guidance.promptGuidelines.";
        };
      };
      disabledForModels = packageLib.nullable (types.listOf disabledEntryType) // {
        description = "Advisor disabledForModels entries.";
      };
      extraConfig = lib.mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Additional rpiv-advisor config fields.";
      };
      environment = lib.mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Raw rpiv-advisor environment overrides.";
      };
    };

  config = lib.mkIf cfg.enable {
    pi.packageEntries = [ (packageLib.packageEntry cfg) ];
    pi.files."config/rpiv-advisor/advisor.json" = advisorConfig;
    pi.agentDirEnvironment.RPIV_ADVISOR_CONFIG_PATH = "config/rpiv-advisor/advisor.json";
    pi.environment = cfg.environment;
  };
}
