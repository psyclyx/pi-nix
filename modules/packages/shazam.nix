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
  cfg = config.pi.packages.shazam;
  entry = packageLib.registryEntry registry "shazam";
  source = packageLib.npmPackageSource {
    inherit pkgs entry;
    patches = ''
      substituteInPlace "$out/dist/core/cache.js" \
        --replace-fail 'function getCacheRoot() {' \
        $'function getCacheRoot() {\n    const managed = process.env.PI_SHAZAM_DIR?.trim();\n    if (managed) return join(managed, "cache");'

        substituteInPlace "$out/dist/core/audit-log.js" \
          --replace-fail 'export const AUDIT_LOG_DIR = join(homedir(), ".pi", "hooks", "audit");' \
          'export const AUDIT_LOG_DIR = process.env.PI_SHAZAM_DIR?.trim() ? join(process.env.PI_SHAZAM_DIR.trim(), "hooks", "audit") : join(homedir(), ".pi", "hooks", "audit");'

        substituteInPlace "$out/dist/index.js" \
          --replace-fail 'if (!isPreCommitHookInstalled(projectRoot)) {' \
          'if (process.env.PI_SHAZAM_AUTO_INSTALL_PRE_COMMIT === "1" && !isPreCommitHookInstalled(projectRoot)) {'

      substituteInPlace "$out/dist/index.js" \
        --replace-fail 'const internalLogPath = join(homedir(), ".pi", "hooks", "audit", "internal.log");' \
        $'const auditLogDir = process.env.PI_SHAZAM_DIR?.trim() ? join(process.env.PI_SHAZAM_DIR.trim(), "hooks", "audit") : join(homedir(), ".pi", "hooks", "audit");\n                const internalLogPath = join(auditLogDir, "internal.log");'

      substituteInPlace "$out/dist/index.js" \
        --replace-fail 'const callsLogPath = join(homedir(), ".pi", "hooks", "audit", "shazam-calls.log");' \
        'const callsLogPath = join(auditLogDir, "shazam-calls.log");'
    '';
  };
in
{
  options.pi.packages.shazam =
    packageLib.packageResourceOptions {
      defaultSource = source;
      description = "Shazam codebase awareness tools for Pi";
    }
    // {
      homeOnly = packageLib.nullable types.bool // {
        description = "PI_SHAZAM_HOME_ONLY for the MCP entrypoint.";
      };
      projectRoot = packageLib.nullable types.str // {
        description = "PI_SHAZAM_PROJECT_ROOT for the MCP entrypoint.";
      };
      autoInstallPreCommitHook = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Whether Shazam should auto-install its Git pre-commit hook into the current project.";
      };
      environment = lib.mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Raw Shazam environment overrides.";
      };
    };

  config = lib.mkIf cfg.enable {
    pi.packageEntries = [ (packageLib.packageEntry cfg) ];
    pi.agentDirEnvironment.PI_SHAZAM_DIR = "shazam";
    pi.environment =
      packageLib.clean {
        PI_SHAZAM_HOME_ONLY =
          if cfg.homeOnly == null then
            null
          else if cfg.homeOnly then
            "1"
          else
            "0";
        PI_SHAZAM_PROJECT_ROOT = cfg.projectRoot;
        PI_SHAZAM_AUTO_INSTALL_PRE_COMMIT = if cfg.autoInstallPreCommitHook then "1" else "0";
      }
      // cfg.environment;
  };
}
