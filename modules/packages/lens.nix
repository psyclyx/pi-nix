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
  cfg = config.pi.packages.lens;
  entry = packageLib.registryEntry registry "lens";
  source = packageLib.npmPackageSource {
    inherit pkgs entry;
    patches = ''
      substituteInPlace "$out/dist/clients/file-utils.js" \
        --replace-fail 'return path.join(os.homedir(), ".pi-lens");' \
        $'const configured = process.env.PI_LENS_DIR?.trim();\n    return configured ? path.resolve(configured) : path.join(os.homedir(), ".pi-lens");'

            substituteInPlace "$out/dist/index.js" \
              --replace-fail 'const DEBUG_LOG_DIR = path.join(os.homedir(), ".pi-lens");' \
              'const DEBUG_LOG_DIR = process.env.PI_LENS_DIR?.trim() ? path.resolve(process.env.PI_LENS_DIR.trim()) : path.join(os.homedir(), ".pi-lens");'

      substituteInPlace "$out/dist/clients/diagnostic-logger.js" \
        --replace-fail 'const home = os.homedir();' \
        'const configured = process.env.PI_LENS_DIR?.trim();'

      substituteInPlace "$out/dist/clients/diagnostic-logger.js" \
        --replace-fail 'const logDir = path.join(home, ".pi-lens", "logs");' \
        'const logDir = path.join(configured ? path.resolve(configured) : path.join(os.homedir(), ".pi-lens"), "logs");'

      substituteInPlace "$out/dist/clients/project-lens-config.js" \
        --replace-fail 'export function findPiLensProjectConfig(startDir) {' \
        $'export function findPiLensProjectConfig(startDir) {\n    if (process.env.PI_LENS_PROJECT_CONFIG === "0")\n        return undefined;'

      substituteInPlace "$out/dist/clients/lsp/config.js" \
        --replace-fail 'export async function loadLSPConfig(cwd) {' \
        $'export async function loadLSPConfig(cwd) {\n    if (process.env.PI_LENS_PROJECT_CONFIG === "0")\n        return {};'
    '';
  };
  lensConfig =
    packageLib.clean {
      inherit (cfg) ignore;
      dispatch = packageLib.clean cfg.dispatch;
      widget = packageLib.clean cfg.widget;
      format = packageLib.clean cfg.format;
      actionableWarnings = packageLib.clean {
        inherit (cfg.actionableWarnings)
          deltaOnly
          enabled
          includeLspCodeActions
          ;
        autoFix = packageLib.clean cfg.actionableWarnings.autoFix;
      };
      contextInjection = packageLib.clean cfg.contextInjection;
    }
    // cfg.extraConfig;
in
{
  options.pi.packages.lens =
    packageLib.packageResourceOptions {
      defaultSource = source;
      description = "Pi Lens code feedback, diagnostics, and formatting tools";
    }
    // {
      ignore = packageLib.nullable (types.listOf types.str) // {
        description = "Global ignore patterns.";
      };
      dispatch.runnerTimeoutFloorMs = packageLib.nullable types.int // {
        description = "dispatch.runnerTimeoutFloorMs.";
      };
      widget.visible = packageLib.nullable types.bool // {
        description = "widget.visible.";
      };
      format = {
        enabled = packageLib.nullable types.bool // {
          description = "format.enabled.";
        };
        mode =
          packageLib.nullable (
            types.enum [
              "deferred"
              "immediate"
            ]
          )
          // {
            description = "format.mode.";
          };
      };
      actionableWarnings = {
        enabled = packageLib.nullable types.bool // {
          description = "actionableWarnings.enabled.";
        };
        includeLspCodeActions = packageLib.nullable types.bool // {
          description = "actionableWarnings.includeLspCodeActions.";
        };
        deltaOnly = packageLib.nullable types.bool // {
          description = "actionableWarnings.deltaOnly.";
        };
        autoFix.enabled = packageLib.nullable types.bool // {
          description = "actionableWarnings.autoFix.enabled.";
        };
      };
      contextInjection.enabled = packageLib.nullable types.bool // {
        description = "contextInjection.enabled.";
      };
      projectConfig = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Whether pi-lens should read project-local .pi-lens.json, pi-lens.json, and LSP config files.";
      };
      environment = lib.mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Raw pi-lens environment overrides such as PI_LENS_* or PILENS_DATA_DIR.";
      };
      extraConfig = lib.mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Additional pi-lens global config fields.";
      };
    };

  config = lib.mkIf cfg.enable {
    pi.packageEntries = [ (packageLib.packageEntry cfg) ];
    pi.files."config/pi-lens/config.json" = lensConfig;
    pi.agentDirEnvironment = {
      PI_LENS_CONFIG_PATH = "config/pi-lens/config.json";
      PI_LENS_DIR = "pi-lens";
      PILENS_DATA_DIR = "pi-lens/projects";
    };
    pi.environment = {
      PI_LENS_PROJECT_CONFIG = if cfg.projectConfig then "1" else "0";
    }
    // cfg.environment;
  };
}
