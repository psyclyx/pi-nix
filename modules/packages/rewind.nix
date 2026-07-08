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
  cfg = config.pi.packages.rewind;
  entry = packageLib.registryEntry registry "rewind";
  source = packageLib.npmPackageSource {
    inherit pkgs entry;
    patches = ''
      substituteInPlace "$out/@ayulab__pi-checkpoint.js" \
        --replace-fail 'return path.join(os.homedir(), ".pi", "agent", "ayu", "checkpoints", "sessions");' \
        'return process.env.PI_REWIND_DIR || (process.env.PI_CODING_AGENT_DIR ? path.join(process.env.PI_CODING_AGENT_DIR, "ayu", "checkpoints", "sessions") : path.join(os.homedir(), ".pi", "agent", "ayu", "checkpoints", "sessions"));'

      substituteInPlace "$out/index.js" \
        --replace-fail 'const mergedSettings = mergeSettingsRecords(await readSettingsRecord(path.join(os.homedir(), ".pi", "agent")), await readSettingsRecord(path.join(ctx.cwd, ".pi")));' \
        $'const managedConfigDir = process.env.PI_REWIND_CONFIG_DIR?.trim() || process.env.PI_CODING_AGENT_DIR || path.join(os.homedir(), ".pi", "agent");\n\t\tconst projectSettings = process.env.PI_REWIND_PROJECT_CONFIG === "1" ? await readSettingsRecord(path.join(ctx.cwd, ".pi")) : {};\n\t\tconst mergedSettings = mergeSettingsRecords(await readSettingsRecord(managedConfigDir), projectSettings);'
    '';
  };
  ayuSettings = packageLib.clean {
    checkpoint = packageLib.clean {
      inherit (cfg.checkpoint)
        enabled
        autoCheckpoint
        restoreOnFork
        restoreOnClone
        restoreOnResume
        restoreOnTree
        defaultSummaryInstructions
        exclude
        include
        maxFileMB
        ;
    };
    rewind = packageLib.clean {
      inherit (cfg.rewind) restoreOnTree;
    };
  };
in
{
  options.pi.packages.rewind =
    packageLib.packageResourceOptions {
      defaultSource = source;
      description = "Ayu checkpoint and /rewind support for Pi";
    }
    // {
      checkpoint = {
        enabled = packageLib.nullable types.bool // {
          description = "ayu.checkpoint.enabled.";
        };
        autoCheckpoint = packageLib.nullable types.bool // {
          description = "ayu.checkpoint.autoCheckpoint.";
        };
        restoreOnFork = packageLib.nullable types.bool // {
          description = "ayu.checkpoint.restoreOnFork.";
        };
        restoreOnClone = packageLib.nullable types.bool // {
          description = "ayu.checkpoint.restoreOnClone.";
        };
        restoreOnResume = packageLib.nullable types.bool // {
          description = "ayu.checkpoint.restoreOnResume.";
        };
        restoreOnTree = packageLib.nullable types.bool // {
          description = "ayu.checkpoint.restoreOnTree.";
        };
        defaultSummaryInstructions = packageLib.nullable types.str // {
          description = "ayu.checkpoint.defaultSummaryInstructions.";
        };
        exclude = packageLib.nullable (types.listOf types.str) // {
          description = "ayu.checkpoint.exclude.";
        };
        include = packageLib.nullable (types.listOf types.str) // {
          description = "ayu.checkpoint.include.";
        };
        maxFileMB = packageLib.nullable types.float // {
          description = "ayu.checkpoint.maxFileMB.";
        };
      };
      rewind.restoreOnTree =
        packageLib.nullable (
          types.enum [
            "always"
            "ask"
            "never"
          ]
        )
        // {
          description = "ayu.rewind.restoreOnTree.";
        };
      projectConfig = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Read project .pi/settings.json for ayu settings.";
      };
      gitPackage = lib.mkOption {
        type = types.nullOr types.package;
        default = pkgs.git;
        description = "Git package used by checkpoint storage operations.";
      };
      environment = lib.mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Raw pi-rewind environment overrides.";
      };
    };

  config = lib.mkIf cfg.enable {
    pi.packageEntries = [ (packageLib.packageEntry cfg) ];
    pi.settings = lib.optionalAttrs (ayuSettings != { }) {
      ayu = ayuSettings;
    };
    pi.agentDirEnvironment = {
      PI_REWIND_CONFIG_DIR = ".";
      PI_REWIND_DIR = "ayu/checkpoints/sessions";
    };
    pi.environment = {
      PI_REWIND_PROJECT_CONFIG = if cfg.projectConfig then "1" else "0";
    }
    // cfg.environment;
    pi.extraPackages = lib.optional (cfg.gitPackage != null) cfg.gitPackage;
  };
}
