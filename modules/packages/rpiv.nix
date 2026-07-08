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
  cfg = config.pi.packages.rpiv;
  entry = packageLib.registryEntry registry "rpiv";
  piPeer = packageLib.piPackageNodeModule (piPackages.pi or config.pi.package);
  typebox = piPeer "typebox";
  yaml = piPeer "yaml";
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
      inherit typebox yaml;
      "@juicesharp/rpiv-advisor" = config.pi.packages.rpivAdvisor.source;
      "@juicesharp/rpiv-args" = config.pi.packages.rpivArgs.source;
      "@juicesharp/rpiv-ask-user-question" = config.pi.packages.askUserQuestion.source;
      "@juicesharp/rpiv-config" = rpivConfig;
      "@juicesharp/rpiv-i18n" = config.pi.packages.rpivI18n.source;
      "@juicesharp/rpiv-todo" = config.pi.packages.todo.source;
      "@juicesharp/rpiv-web-tools" = config.pi.packages.rpivWebTools.source;
      "@juicesharp/rpiv-workflow" = config.pi.packages.rpivWorkflow.source;
    };
    patches = ''
      substituteInPlace "$out/extensions/rpiv-core/models-config.ts" \
        --replace-fail 'export const CONFIG_PATH = configPath("rpiv-pi", "models.json");' \
        'export const CONFIG_PATH = process.env.RPIV_PI_MODELS_CONFIG_PATH?.trim() || configPath("rpiv-pi", "models.json");'

      substituteInPlace "$out/extensions/rpiv-core/guidance.ts" \
        --replace-fail 'export function injectRootGuidance(cwd: string, pi: ExtensionAPI): void {' \
        $'export function injectRootGuidance(cwd: string, pi: ExtensionAPI): void {\n\tif (process.env.RPIV_PI_PROJECT_GUIDANCE !== "1") return;'

      substituteInPlace "$out/extensions/rpiv-core/guidance.ts" \
        --replace-fail $'export function handleToolCallGuidance(\n\tevent: { toolName: string; input: Record<string, unknown> },\n\tctx: { cwd: string },\n\tpi: ExtensionAPI,\n): void {' \
        $'export function handleToolCallGuidance(\n\tevent: { toolName: string; input: Record<string, unknown> },\n\tctx: { cwd: string },\n\tpi: ExtensionAPI,\n): void {\n\tif (process.env.RPIV_PI_PROJECT_GUIDANCE !== "1") return;'

      substituteInPlace "$out/extensions/rpiv-core/session-hooks.ts" \
        --replace-fail 'function migrateThoughtsToArtifacts(cwd: string): void {' \
        $'function migrateThoughtsToArtifacts(cwd: string): void {\n\tif (process.env.RPIV_PI_MIGRATE_THOUGHTS !== "1") return;'
    '';
  };
  thinkingValues = [
    "off"
    "minimal"
    "low"
    "medium"
    "high"
    "xhigh"
  ];
  modelEntryType = types.either types.str (
    types.submodule {
      options = {
        model = packageLib.nullable types.str // {
          description = "Model key in provider/model form.";
        };
        thinking = packageLib.nullable (types.enum thinkingValues) // {
          description = "Thinking level override.";
        };
      };
    }
  );
  presetType = types.submodule {
    options.stages = lib.mkOption {
      type = types.attrsOf modelEntryType;
      default = { };
      description = "Per-stage model overrides for this workflow preset.";
    };
  };
  modelsConfig = packageLib.clean {
    inherit (cfg.models)
      defaults
      agents
      stages
      skills
      presets
      ;
  };
  siblingConfig = lib.mkIf cfg.enableRecommendedSiblings {
    pi.packages.askUserQuestion.enable = lib.mkDefault true;
    pi.packages.rpivAdvisor.enable = lib.mkDefault true;
    pi.packages.rpivArgs.enable = lib.mkDefault true;
    pi.packages.rpivI18n.enable = lib.mkDefault true;
    pi.packages.rpivWebTools.enable = lib.mkDefault true;
    pi.packages.rpivWorkflow.enable = lib.mkDefault true;
    pi.packages.subagents.enable = lib.mkDefault true;
    pi.packages.todo.enable = lib.mkDefault true;
  };
in
{
  options.pi.packages.rpiv =
    packageLib.packageResourceOptions {
      defaultSource = source;
      description = "RPiV skill-based development workflow";
    }
    // {
      enableRecommendedSiblings = lib.mkOption {
        type = types.bool;
        default = true;
        description = "Enable rpiv's sibling packages with mkDefault so users can still override individual packages.";
      };
      projectGuidance = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Read project .rpiv/guidance and nested AGENTS.md/CLAUDE.md files for rpiv guidance injection.";
      };
      migrateThoughts = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Allow rpiv to migrate project thoughts/shared into .rpiv/artifacts on session start.";
      };
      models = {
        defaults = packageLib.nullable modelEntryType // {
          description = "Default rpiv model override.";
        };
        agents = lib.mkOption {
          type = types.attrsOf modelEntryType;
          default = { };
          description = "Model overrides keyed by bundled agent name.";
        };
        stages = lib.mkOption {
          type = types.attrsOf modelEntryType;
          default = { };
          description = "Model overrides keyed by workflow stage.";
        };
        skills = lib.mkOption {
          type = types.attrsOf modelEntryType;
          default = { };
          description = "Model overrides keyed by skill name.";
        };
        presets = lib.mkOption {
          type = types.attrsOf presetType;
          default = { };
          description = "Workflow preset model overrides.";
        };
      };
      environment = lib.mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Raw rpiv-pi environment overrides.";
      };
    };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      siblingConfig
      {
        pi.packageEntries = [ (packageLib.packageEntry cfg) ];
        pi.files."config/rpiv-pi/models.json" = modelsConfig;
        pi.agentDirEnvironment.RPIV_PI_MODELS_CONFIG_PATH = "config/rpiv-pi/models.json";
        pi.environment = {
          RPIV_PI_MIGRATE_THOUGHTS = if cfg.migrateThoughts then "1" else "0";
          RPIV_PI_PROJECT_GUIDANCE = if cfg.projectGuidance then "1" else "0";
        }
        // cfg.environment;
      }
    ]
  );
}
