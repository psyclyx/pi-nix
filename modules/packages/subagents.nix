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
  cfg = config.pi.packages.subagents;
  entry = packageLib.registryEntry registry "subagents";

  waitToolType = types.either types.bool (
    types.submodule {
      options.enabled = packageLib.nullable types.bool // {
        description = "Enable the subagent wait tool.";
      };
    }
  );

  toolBudgetType = types.submodule {
    options = {
      soft = packageLib.nullable types.int // {
        description = "Soft tool-call budget.";
      };
      hard = packageLib.nullable types.int // {
        description = "Hard tool-call budget.";
      };
      block = packageLib.nullable (types.either types.str (types.listOf types.str)) // {
        description = "Tools to block after hard budget, or *.";
      };
    };
  };

  subagentSettings = packageLib.clean {
    inherit (cfg.settings)
      defaultModel
      disableBuiltins
      disableThinking
      agentOverrides
      ;
    modelScope = packageLib.clean cfg.settings.modelScope;
  };

  extensionConfig =
    packageLib.clean {
      inherit (cfg.config)
        asyncByDefault
        toolDescriptionMode
        forceTopLevelAsync
        waitTool
        defaultSessionDir
        singleRunOutputBaseDir
        maxSubagentDepth
        maxSubagentSpawnsPerSession
        globalConcurrencyLimit
        worktreeSetupHook
        worktreeSetupHookTimeoutMs
        worktreeBaseDir
        ;
      control = packageLib.clean cfg.config.control;
      completionBatch = packageLib.clean cfg.config.completionBatch;
      turnBudget = packageLib.clean cfg.config.turnBudget;
      toolBudget = packageLib.clean cfg.config.toolBudget;
      parallel = packageLib.clean cfg.config.parallel;
      chain = packageLib.clean {
        dynamicFanout = packageLib.clean cfg.config.chain.dynamicFanout;
      };
      intercomBridge = packageLib.clean cfg.config.intercomBridge;
      proactiveSkillSubagents =
        if cfg.config.proactiveSkillSubagents == null then null else cfg.config.proactiveSkillSubagents;
      scheduledRuns = packageLib.clean cfg.config.scheduledRuns;
    }
    // cfg.config.extraConfig;
in
{
  options.pi.packages.subagents =
    packageLib.packageResourceOptions {
      defaultSource = packageLib.packageSource {
        inherit pkgs registry entry;
        piPackage = config.pi.package;
      };
      description = "Pi subagent delegation";
    }
    // {
      settings = {
        defaultModel = packageLib.nullable types.str // {
          description = "subagents.defaultModel for agents without an explicit model.";
        };
        disableBuiltins = packageLib.nullable types.bool // {
          description = "Hide bundled builtin agents.";
        };
        disableThinking = packageLib.nullable types.bool // {
          description = "Clear bundled builtin thinking defaults.";
        };
        modelScope = {
          enforce = packageLib.nullable types.bool // {
            description = "Reject subagent models outside allow patterns.";
          };
          allow = packageLib.nullable (types.listOf types.str) // {
            description = "Allowed provider/id glob patterns.";
          };
        };
        agentOverrides = lib.mkOption {
          type = types.attrsOf types.anything;
          default = { };
          description = "subagents.agentOverrides. Supports model, fallbackModels, thinking, tools, skills, prompts, disabled, and related override fields.";
        };
      };

      config = {
        asyncByDefault = packageLib.nullable types.bool // {
          description = "Make top-level calls background execution by default.";
        };
        toolDescriptionMode =
          packageLib.nullable (
            types.enum [
              "full"
              "compact"
              "custom"
            ]
          )
          // {
            description = "Parent-facing subagent tool description mode.";
          };
        forceTopLevelAsync = packageLib.nullable types.bool // {
          description = "Force depth-0 runs into background mode.";
        };
        waitTool = packageLib.nullable waitToolType // {
          description = "Subagent wait tool configuration.";
        };
        defaultSessionDir = packageLib.nullable types.str // {
          description = "Default child session directory.";
        };
        singleRunOutputBaseDir = packageLib.nullable types.str // {
          description = "Base directory for relative single-agent output paths.";
        };
        maxSubagentDepth = packageLib.nullable types.int // {
          description = "Maximum nested delegation depth.";
        };
        maxSubagentSpawnsPerSession = packageLib.nullable types.int // {
          description = "Maximum child launches per parent session.";
        };
        globalConcurrencyLimit = packageLib.nullable types.int // {
          description = "Global cap on simultaneously-running subagent tasks in one run.";
        };

        control = {
          enabled = packageLib.nullable types.bool // {
            description = "Enable control/attention notices.";
          };
          needsAttentionAfterMs = packageLib.nullable types.int // {
            description = "Delay before needs-attention notices.";
          };
          repeatEveryMs = packageLib.nullable types.int // {
            description = "Repeat interval for attention notices.";
          };
          maxNotices = packageLib.nullable types.int // {
            description = "Maximum attention notices.";
          };
          notificationChannels =
            packageLib.nullable (
              types.listOf (
                types.enum [
                  "event"
                  "async"
                  "intercom"
                ]
              )
            )
            // {
              description = "Control notification channels.";
            };
        };

        completionBatch = {
          enabled = packageLib.nullable types.bool // {
            description = "Batch async completion notifications.";
          };
          debounceMs = packageLib.nullable types.int // {
            description = "Batch debounce window.";
          };
          maxWaitMs = packageLib.nullable types.int // {
            description = "Maximum batch wait.";
          };
          stragglerDebounceMs = packageLib.nullable types.int // {
            description = "Shorter idle window for straggler completions.";
          };
        };

        turnBudget = {
          maxTurns = packageLib.nullable types.int // {
            description = "Maximum child assistant turns before warning.";
          };
          graceTurns = packageLib.nullable types.int // {
            description = "Assistant turns allowed after warning.";
          };
        };
        toolBudget = lib.mkOption {
          type = toolBudgetType;
          default = { };
          description = "Default child tool-call budget.";
        };

        parallel = {
          maxTasks = packageLib.nullable types.int // {
            description = "Maximum top-level parallel tasks.";
          };
          concurrency = packageLib.nullable types.int // {
            description = "Default top-level parallel concurrency.";
          };
        };
        chain.dynamicFanout.maxItems = packageLib.nullable types.int // {
          description = "Maximum dynamic fanout items.";
        };

        worktreeSetupHook = packageLib.nullable types.str // {
          description = "Worktree setup hook command.";
        };
        worktreeSetupHookTimeoutMs = packageLib.nullable types.int // {
          description = "Worktree setup hook timeout.";
        };
        worktreeBaseDir = packageLib.nullable types.str // {
          description = "Base directory for subagent worktrees.";
        };

        intercomBridge = {
          mode =
            packageLib.nullable (
              types.enum [
                "off"
                "fork-only"
                "always"
              ]
            )
            // {
              description = "Intercom bridge mode.";
            };
          instructionFile = packageLib.nullable types.str // {
            description = "Intercom bridge instruction file.";
          };
        };

        proactiveSkillSubagents =
          packageLib.nullable (
            types.either types.bool (
              types.submodule {
                options = {
                  enabled = packageLib.nullable types.bool // {
                    description = "Enable proactive subagent skill recommendations.";
                  };
                  minReferences = packageLib.nullable types.int // {
                    description = "Minimum references before recommending.";
                  };
                  maxRecommendations = packageLib.nullable types.int // {
                    description = "Maximum recommendations.";
                  };
                  preferredAgent = packageLib.nullable types.str // {
                    description = "Preferred agent for proactive skill recommendations.";
                  };
                };
              }
            )
          )
          // {
            description = "Proactive skill subagent configuration, or false.";
          };

        scheduledRuns = {
          enabled = packageLib.nullable types.bool // {
            description = "Enable scheduled subagent runs.";
          };
          maxLatenessMs = packageLib.nullable types.int // {
            description = "Maximum lateness before a missed scheduled job is skipped.";
          };
          maxPending = packageLib.nullable types.int // {
            description = "Maximum pending scheduled jobs per session.";
          };
        };

        extraConfig = lib.mkOption {
          type = types.attrsOf types.anything;
          default = { };
          description = "Additional extensions/subagent/config.json fields.";
        };
      };
    };

  config = lib.mkIf cfg.enable {
    pi.packageEntries = lib.mkOrder 100 [ (packageLib.packageEntry cfg) ];
    pi.settings = lib.optionalAttrs (subagentSettings != { }) {
      subagents = subagentSettings;
    };
    pi.files = lib.optionalAttrs (extensionConfig != { }) {
      "extensions/subagent/config.json" = extensionConfig;
    };
  };
}
