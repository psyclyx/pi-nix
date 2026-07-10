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
  cfg = config.pi.packages;

  registryEntry = name: packageLib.registryEntry registry name;
  defaultSource =
    name:
    packageLib.packageSource {
      inherit pkgs registry;
      entry = registryEntry name;
      piPackage = config.pi.package;
    };
  packageOptions =
    name: description:
    packageLib.packageResourceOptions {
      defaultSource = defaultSource name;
      inherit description;
    };

  enabledPackage =
    attr: order:
    lib.mkIf cfg.${attr}.enable {
      pi.packageEntries = lib.mkOrder order [ (packageLib.packageEntry cfg.${attr}) ];
    };

  simplePackages = {
    askUser = {
      registryName = "pi-ask-user";
      order = 110;
      description = "Ask-user dialog and clarification tools";
    };
    plan = {
      registryName = "plan";
      order = 150;
      description = "Planning helper commands";
    };
    simplify = {
      registryName = "simplify";
      order = 160;
      description = "Simplification helper command";
    };
    addDir = {
      registryName = "add-dir";
      order = 170;
      description = "Add directories to the current Pi session";
    };
    claudeCli = {
      registryName = "claude-cli";
      order = 190;
      description = "Claude CLI bridge for Pi";
    };
    usage = {
      registryName = "usage";
      order = 330;
      description = "Pi usage display extension";
    };
    rawPaste = {
      registryName = "raw-paste";
      order = 340;
      description = "Paste raw text into Pi";
    };
    todos = {
      registryName = "todos";
      order = 350;
      description = "Todo-list management tools";
    };
    autoresearch = {
      registryName = "autoresearch";
      order = 380;
      description = "AutoResearch workflow extension";
    };
    ralphWiggum = {
      registryName = "ralph-wiggum";
      order = 390;
      description = "Ralph Wiggum iterative research helper";
    };
  };

  simpleOptions =
    lib.mapAttrs
      (_: spec: packageOptions spec.registryName spec.description)
      simplePackages;
  simpleConfigs = lib.mapAttrsToList (attr: spec: enabledPackage attr spec.order) simplePackages;

  nullOrAttrs = types.nullOr (types.attrsOf types.anything);
  attrsOption =
    description:
    lib.mkOption {
      type = types.attrsOf types.anything;
      default = { };
      inherit description;
    };
  stringListOption =
    description:
    lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      inherit description;
    };

  promptTemplateConfig =
    packageLib.clean {
      toolEnabled = cfg.promptTemplates.tool.enabled;
      toolGuidance = cfg.promptTemplates.tool.guidance;
    }
    // cfg.promptTemplates.extraConfig;

  plannotatorConfig =
    packageLib.clean {
      defaults = if cfg.plannotator.defaults == { } then null else cfg.plannotator.defaults;
      phases = if cfg.plannotator.phases == { } then null else cfg.plannotator.phases;
    }
    // cfg.plannotator.extraConfig;

  powerbarSettings =
    packageLib.clean {
      left = if cfg.powerbar.left == [ ] then null else lib.concatStringsSep "," cfg.powerbar.left;
      right = if cfg.powerbar.right == [ ] then null else lib.concatStringsSep "," cfg.powerbar.right;
      separator = cfg.powerbar.separator;
      placement = cfg.powerbar.placement;
      "bar-style" = cfg.powerbar.barStyle;
      "bar-width" = if cfg.powerbar.barWidth == null then null else toString cfg.powerbar.barWidth;
    };

  extensionSettingsConfig =
    cfg.extensionSettings.settings
    // lib.optionalAttrs (powerbarSettings != { }) {
      powerbar = (cfg.extensionSettings.settings.powerbar or { }) // powerbarSettings;
    };

  slopchopBuiltins = lib.optionalAttrs (cfg.slopchop.disableBuiltins != [ ]) {
    disable = cfg.slopchop.disableBuiltins;
  };
  slopchopConfig =
    packageLib.clean {
      inherit (cfg.slopchop) version globalShortcut;
      builtins = if slopchopBuiltins == { } then null else slopchopBuiltins;
      shortcuts = if cfg.slopchop.shortcuts == [ ] then null else cfg.slopchop.shortcuts;
    }
    // cfg.slopchop.extraConfig;

  interactiveSpawn =
    packageLib.clean {
      inherit (cfg.interactiveShell.spawn)
        defaultAgent
        shortcut
        worktree
        worktreeBaseDir
        ;
      commands =
        if cfg.interactiveShell.spawn.commands == { } then null else cfg.interactiveShell.spawn.commands;
      defaultArgs =
        if cfg.interactiveShell.spawn.defaultArgs == { } then null else cfg.interactiveShell.spawn.defaultArgs;
    };
  interactiveShellConfig =
    packageLib.clean {
      inherit (cfg.interactiveShell)
        overlayWidthPercent
        overlayHeightPercent
        focusShortcut
        scrollbackLines
        exitAutoCloseDelay
        minQueryIntervalSeconds
        transferLines
        transferMaxChars
        completionNotifyLines
        completionNotifyMaxChars
        handsFreeUpdateMode
        handsFreeUpdateInterval
        handsFreeQuietThreshold
        autoExitGracePeriod
        handsFreeUpdateMaxChars
        handsFreeMaxTotalChars
        handoffPreviewEnabled
        handoffPreviewLines
        handoffPreviewMaxChars
        handoffSnapshotEnabled
        handoffSnapshotLines
        handoffSnapshotMaxChars
        ansiReemit
        ;
      spawn = interactiveSpawn;
    }
    // cfg.interactiveShell.extraConfig;

  memoryHooks =
    packageLib.clean {
      sessionStart = if cfg.memory.hooks.sessionStart == [ ] then null else cfg.memory.hooks.sessionStart;
      sessionEnd = if cfg.memory.hooks.sessionEnd == [ ] then null else cfg.memory.hooks.sessionEnd;
      beforeAgentStart =
        if cfg.memory.hooks.beforeAgentStart == [ ] then null else cfg.memory.hooks.beforeAgentStart;
    };
  memoryConfig =
    packageLib.clean {
      enabled = cfg.memory.extensionEnabled;
      delivery = cfg.memory.delivery;
      memoryDir = packageLib.clean cfg.memory.memoryDir;
      hooks = memoryHooks;
      tape = if cfg.memory.tape == { } then null else cfg.memory.tape;
    }
    // cfg.memory.extraConfig;

  themeOptions =
    name: description:
    packageOptions name description
    // {
      theme = packageLib.nullable types.str // {
        description = "Theme name to write to settings.json when this theme package is enabled.";
      };
    };

  compoundEntry = registryEntry "compound";
  compoundSource = packageLib.packageSource {
    inherit pkgs registry;
    entry = compoundEntry;
    piPackage = config.pi.package;
  };
  compoundPiPackage =
    pkgs.runCommand "compound-engineering-pi-${compoundEntry.version}" { nativeBuildInputs = [ pkgs.bun ]; } ''
      mkdir -p "$out/agent"
      export HOME="$TMPDIR"
      export XDG_CACHE_HOME="$TMPDIR/cache"
      bun run ${compoundSource}/src/index.ts install ${compoundSource}/plugins/compound-engineering --to pi --pi-home "$out/agent"
      cat > "$out/package.json" <<JSON
      {
        "name": "@pi-nix/compound-engineering",
        "version": "${compoundEntry.version}",
        "private": true,
        "pi": {
          "extensions": [
            "./agent/extensions"
          ],
          "skills": [
            "./agent/skills"
          ],
          "prompts": [
            "./agent/prompts"
          ],
          "subagents": {
            "agents": [
              "./agent/agents"
            ]
          }
        }
      }
JSON
    '';
in
{
  options.pi.packages =
    simpleOptions
    // {
      promptTemplates =
        packageOptions "prompt-templates" "Prompt template model and prompt resources"
        // {
          tool = {
            enabled = packageLib.nullable types.bool // {
              description = "Enable the prompt-template tool.";
            };
            guidance = packageLib.nullable types.str // {
              description = "Guidance text used by the prompt-template tool.";
            };
          };
          extraConfig = attrsOption "Additional prompt-template-model.json fields.";
        };

      plannotator =
        packageOptions "plannotator" "Planning annotation workflow extension"
        // {
          defaults = lib.mkOption {
            type = nullOrAttrs;
            default = { };
            description = "Default Plannotator phase profile.";
          };
          phases = attrsOption "Plannotator phase profiles keyed by phase name.";
          dataDir = packageLib.nullable types.str // {
            description = "PLANNOTATOR_DATA_DIR override.";
          };
          extraConfig = attrsOption "Additional plannotator.json fields.";
        };

      slopchop =
        packageOptions "slopchop" "Diff hunk review shortcuts"
        // {
          version = packageLib.nullable types.int // {
            description = "slopchop.json config version.";
          };
          globalShortcut = packageLib.nullable types.str // {
            description = "Global SlopChop shortcut.";
          };
          disableBuiltins = stringListOption "Built-in SlopChop shortcuts to disable.";
          shortcuts = lib.mkOption {
            type = types.listOf (types.attrsOf types.anything);
            default = [ ];
            description = "Custom SlopChop shortcut definitions.";
          };
          extraConfig = attrsOption "Additional extensions/slopchop.json fields.";
        };

      extensionSettings =
        packageOptions "extension-settings" "Shared per-extension settings UI"
        // {
          settings = lib.mkOption {
            type = types.attrsOf (types.attrsOf types.anything);
            default = { };
            description = "settings-extensions.json contents keyed by extension name.";
          };
        };

      powerbar =
        packageOptions "powerbar" "Status powerbar for Pi"
        // {
          left = stringListOption "Powerbar left segment names.";
          right = stringListOption "Powerbar right segment names.";
          separator = packageLib.nullable types.str // {
            description = "Powerbar separator string.";
          };
          placement =
            packageLib.nullable (
              types.enum [
                "belowEditor"
                "aboveEditor"
              ]
            )
            // {
              description = "Powerbar placement.";
            };
          barStyle =
            packageLib.nullable (
              types.enum [
                "continuous"
                "blocks"
              ]
            )
            // {
              description = "Powerbar context bar style.";
            };
          barWidth = packageLib.nullable types.int // {
            description = "Powerbar context bar width.";
          };
        };

      interactiveShell =
        packageOptions "interactive-shell" "Interactive shell overlay for Pi"
        // {
          overlayWidthPercent = packageLib.nullable types.int // {
            description = "Interactive shell overlay width percent.";
          };
          overlayHeightPercent = packageLib.nullable types.int // {
            description = "Interactive shell overlay height percent.";
          };
          focusShortcut = packageLib.nullable types.str // {
            description = "Interactive shell focus shortcut.";
          };
          spawn = {
            defaultAgent =
              packageLib.nullable (
                types.enum [
                  "pi"
                  "codex"
                  "claude"
                  "cursor"
                ]
              )
              // {
                description = "Default agent used by the spawn command.";
              };
            shortcut = packageLib.nullable types.str // {
              description = "Spawn shortcut.";
            };
            commands = lib.mkOption {
              type = types.attrsOf types.str;
              default = { };
              description = "Spawn command overrides keyed by agent.";
            };
            defaultArgs = lib.mkOption {
              type = types.attrsOf (types.listOf types.str);
              default = { };
              description = "Default spawn arguments keyed by agent.";
            };
            worktree = packageLib.nullable types.bool // {
              description = "Spawn child agents in worktrees.";
            };
            worktreeBaseDir = packageLib.nullable types.str // {
              description = "Base directory for spawn worktrees.";
            };
          };
          scrollbackLines = packageLib.nullable types.int // {
            description = "Interactive shell scrollback line count.";
          };
          exitAutoCloseDelay = packageLib.nullable types.int // {
            description = "Delay before closing completed shells.";
          };
          minQueryIntervalSeconds = packageLib.nullable types.int // {
            description = "Minimum interval between shell queries.";
          };
          transferLines = packageLib.nullable types.int // {
            description = "Lines transferred to the agent.";
          };
          transferMaxChars = packageLib.nullable types.int // {
            description = "Maximum transferred characters.";
          };
          completionNotifyLines = packageLib.nullable types.int // {
            description = "Completion notification lines.";
          };
          completionNotifyMaxChars = packageLib.nullable types.int // {
            description = "Maximum completion notification characters.";
          };
          handsFreeUpdateMode =
            packageLib.nullable (
              types.enum [
                "on-quiet"
                "interval"
              ]
            )
            // {
              description = "Hands-free update mode.";
            };
          handsFreeUpdateInterval = packageLib.nullable types.int // {
            description = "Hands-free interval in milliseconds.";
          };
          handsFreeQuietThreshold = packageLib.nullable types.int // {
            description = "Quiet threshold before hands-free update.";
          };
          autoExitGracePeriod = packageLib.nullable types.int // {
            description = "Grace period before auto-exit.";
          };
          handsFreeUpdateMaxChars = packageLib.nullable types.int // {
            description = "Maximum hands-free update characters.";
          };
          handsFreeMaxTotalChars = packageLib.nullable types.int // {
            description = "Maximum total hands-free characters.";
          };
          handoffPreviewEnabled = packageLib.nullable types.bool // {
            description = "Enable handoff previews.";
          };
          handoffPreviewLines = packageLib.nullable types.int // {
            description = "Handoff preview line count.";
          };
          handoffPreviewMaxChars = packageLib.nullable types.int // {
            description = "Maximum handoff preview characters.";
          };
          handoffSnapshotEnabled = packageLib.nullable types.bool // {
            description = "Enable handoff snapshots.";
          };
          handoffSnapshotLines = packageLib.nullable types.int // {
            description = "Handoff snapshot line count.";
          };
          handoffSnapshotMaxChars = packageLib.nullable types.int // {
            description = "Maximum handoff snapshot characters.";
          };
          ansiReemit = packageLib.nullable types.bool // {
            description = "Re-emit ANSI terminal state.";
          };
          extraConfig = attrsOption "Additional interactive-shell.json fields.";
        };

      memory =
        packageOptions "memory" "Markdown git-backed memory extension"
        // {
          extensionEnabled = packageLib.nullable types.bool // {
            description = "pi-memory-md enabled setting.";
          };
          delivery =
            packageLib.nullable (
              types.enum [
                "message-append"
                "system-prompt"
              ]
            )
            // {
              description = "How memory is delivered into the conversation.";
            };
          memoryDir = {
            repoUrl = packageLib.nullable types.str // {
              description = "Memory repository URL.";
            };
            localPath = packageLib.nullable types.str // {
              description = "Local memory repository path.";
            };
            globalMemory = packageLib.nullable types.bool // {
              description = "Enable global memory.";
            };
          };
          hooks = {
            sessionStart = stringListOption "Actions run when a session starts.";
            sessionEnd = stringListOption "Actions run when a session ends.";
            beforeAgentStart = stringListOption "Actions run before the agent starts.";
          };
          tape = attrsOption "pi-memory-md tape settings.";
          extraConfig = attrsOption "Additional pi-memory-md settings.";
        };

      compound = {
        enable = lib.mkEnableOption "Compound Engineering Pi resources";
      };

      hackerman = themeOptions "hackerman" "Hackerman Pi theme";
      curatedThemes = themeOptions "curated-themes" "Curated Pi themes";
      terminalTheme = themeOptions "terminal-theme" "Terminal Pi themes";
    };

  config = lib.mkMerge (
    simpleConfigs
    ++ [
      (enabledPackage "promptTemplates" 180)
      (enabledPackage "plannotator" 300)
      (enabledPackage "slopchop" 310)
      (enabledPackage "extensionSettings" 320)
      (enabledPackage "powerbar" 325)
      (enabledPackage "interactiveShell" 370)
      (enabledPackage "memory" 140)
      (enabledPackage "hackerman" 420)
      (enabledPackage "curatedThemes" 430)
      (enabledPackage "terminalTheme" 440)

      (lib.mkIf cfg.promptTemplates.enable {
        pi.files = lib.optionalAttrs (promptTemplateConfig != { }) {
          "prompt-template-model.json" = promptTemplateConfig;
        };
      })

      (lib.mkIf cfg.plannotator.enable {
        pi.files = lib.optionalAttrs (plannotatorConfig != { }) {
          "plannotator.json" = plannotatorConfig;
        };
        pi.environment = lib.optionalAttrs (cfg.plannotator.dataDir != null) {
          PLANNOTATOR_DATA_DIR = cfg.plannotator.dataDir;
        };
      })

      (lib.mkIf cfg.slopchop.enable {
        pi.files = lib.optionalAttrs (slopchopConfig != { }) {
          "extensions/slopchop.json" = slopchopConfig;
        };
      })

      (lib.mkIf (cfg.extensionSettings.enable || cfg.powerbar.enable || extensionSettingsConfig != { }) {
        pi.files = lib.optionalAttrs (extensionSettingsConfig != { }) {
          "settings-extensions.json" = extensionSettingsConfig;
        };
      })

      (lib.mkIf cfg.powerbar.enable {
        pi.packages.extensionSettings.enable = lib.mkDefault true;
      })

      (lib.mkIf cfg.interactiveShell.enable {
        pi.files = lib.optionalAttrs (interactiveShellConfig != { }) {
          "interactive-shell.json" = interactiveShellConfig;
        };
      })

      (lib.mkIf cfg.memory.enable {
        pi.settings = lib.optionalAttrs (memoryConfig != { }) {
          "pi-memory-md" = memoryConfig;
        };
      })

      (lib.mkIf cfg.compound.enable {
        pi.packages.subagents.enable = lib.mkDefault true;
        pi.packages.askUser.enable = lib.mkDefault true;
        pi.packageEntries = lib.mkOrder 115 [
          {
            source = "${compoundPiPackage}";
          }
        ];
        pi.runtime.extraArgs = [
          "--append-system-prompt"
          "${compoundPiPackage}/agent/AGENTS.md"
        ];
      })

      (lib.mkIf (cfg.hackerman.enable && cfg.hackerman.theme != null) {
        pi.settings.theme = cfg.hackerman.theme;
      })
      (lib.mkIf (cfg.curatedThemes.enable && cfg.curatedThemes.theme != null) {
        pi.settings.theme = cfg.curatedThemes.theme;
      })
      (lib.mkIf (cfg.terminalTheme.enable && cfg.terminalTheme.theme != null) {
        pi.settings.theme = cfg.terminalTheme.theme;
      })
    ]
  );
}
