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
  cfg = config.pi.packages.rpivWorkflow;
  entry = packageLib.registryEntry registry "rpiv-workflow";
  piPeer = packageLib.piPackageNodeModule (piPackages.pi or config.pi.package);
  typebox = piPeer "typebox";
  jiti = packageLib.npmPackageSource {
    inherit pkgs;
    entry = packageLib.npmRegistryEntry registry "jiti";
  };
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
      inherit jiti;
      inherit typebox;
      "@juicesharp/rpiv-config" = rpivConfig;
    };
    patches = ''
      substituteInPlace "$out/load/paths.ts" \
        --replace-fail $'export function projectOverlayPaths(cwd: string): OverlayPaths {\n\tconst root = join(cwd, ".rpiv", "workflows");\n\treturn { configFile: join(root, "config.ts"), packsDir: join(root, "packs") };\n}' \
        $'export function projectOverlayPaths(cwd: string): OverlayPaths {\n\tconst configured = process.env.RPIV_WORKFLOW_PROJECT_DIR?.trim();\n\tconst root = configured || (process.env.RPIV_WORKFLOW_PROJECT_CONFIG === "1" ? join(cwd, ".rpiv", "workflows") : join(process.env.PI_CODING_AGENT_DIR || cwd, "disabled", "rpiv-workflows-project"));\n\treturn { configFile: join(root, "config.ts"), packsDir: join(root, "packs") };\n}'

      substituteInPlace "$out/load/paths.ts" \
        --replace-fail $'export function userOverlayPaths(): OverlayPaths {\n\treturn {\n\t\tconfigFile: configPath("rpiv-workflow", "config.ts"),\n\t\tpacksDir: configPath("rpiv-workflow", "packs"),\n\t};\n}' \
        $'export function userOverlayPaths(): OverlayPaths {\n\tconst root = process.env.RPIV_WORKFLOW_USER_DIR?.trim();\n\treturn {\n\t\tconfigFile: root ? join(root, "config.ts") : configPath("rpiv-workflow", "config.ts"),\n\t\tpacksDir: root ? join(root, "packs") : configPath("rpiv-workflow", "packs"),\n\t};\n}'

      substituteInPlace "$out/load/legacy.ts" \
        --replace-fail 'if (existsSync(join(cwd, ".rpiv-workflow"))) {' \
        'if (process.env.RPIV_WORKFLOW_PROJECT_CONFIG === "1" && existsSync(join(cwd, ".rpiv-workflow"))) {'

      substituteInPlace "$out/load/legacy.ts" \
        --replace-fail 'if (hasOrphanedRunFiles(cwd)) {' \
        'if (process.env.RPIV_WORKFLOW_PROJECT_CONFIG === "1" && hasOrphanedRunFiles(cwd)) {'

      substituteInPlace "$out/state/paths.ts" \
        --replace-fail $'export function runsDir(cwd: string): string {\n\treturn join(cwd, ".rpiv", "workflows", "runs");\n}' \
        $'export function runsDir(cwd: string): string {\n\treturn process.env.RPIV_WORKFLOW_RUNS_DIR?.trim() || join(cwd, ".rpiv", "workflows", "runs");\n}'
    '';
  };
  typedEnvironment = packageLib.clean {
    RPIV_WORKFLOW_PROJECT_CONFIG =
      if cfg.projectConfig || cfg.projectDirectory != null then "1" else "0";
    RPIV_WORKFLOW_PROJECT_DIR =
      if cfg.projectDirectory == null then null else packageLib.sourceToString cfg.projectDirectory;
    RPIV_WORKFLOW_USER_DIR =
      if cfg.userDirectory == null then null else packageLib.sourceToString cfg.userDirectory;
    RPIV_WORKFLOW_RUNS_DIR =
      if cfg.runsDirectory == null then null else packageLib.sourceToString cfg.runsDirectory;
  };
in
{
  options.pi.packages.rpivWorkflow =
    packageLib.packageResourceOptions {
      defaultSource = source;
      description = "RPiV typed workflow runner";
    }
    // {
      projectConfig = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Read project .rpiv/workflows/config.ts and packs/*.ts.";
      };
      projectDirectory = packageLib.nullable packageLib.sourceType // {
        description = "Explicit project workflow directory containing config.ts and packs/; also enables project config.";
      };
      userDirectory = packageLib.nullable packageLib.sourceType // {
        description = "User workflow directory containing config.ts and packs/. Null uses a managed PI_CODING_AGENT_DIR directory.";
      };
      runsDirectory = packageLib.nullable packageLib.sourceType // {
        description = "Directory for workflow run JSONL state. Null leaves the upstream project .rpiv/workflows/runs default.";
      };
      environment = lib.mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Raw rpiv-workflow environment overrides.";
      };
    };

  config = lib.mkIf cfg.enable {
    pi.packageEntries = [ (packageLib.packageEntry cfg) ];
    pi.agentDirEnvironment = lib.optionalAttrs (cfg.userDirectory == null) {
      RPIV_WORKFLOW_USER_DIR = "config/rpiv-workflow";
    };
    pi.environment = typedEnvironment // cfg.environment;
  };
}
