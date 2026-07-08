{ config, lib, ... }:

let
  inherit (lib) types;
  cfg = config.pi.core;

  nullable =
    type: _default:
    lib.mkOption {
      type = types.nullOr type;
      default = null;
    };

  opt = name: value: lib.optionalAttrs (value != null) { ${name} = value; };
  clean =
    attrs:
    lib.filterAttrs (_: value: value != null && value != { }) (
      lib.mapAttrs (_: value: if builtins.isAttrs value then clean value else value) attrs
    );
  nested =
    name: attrs:
    let
      value = clean attrs;
    in
    lib.optionalAttrs (value != { }) { ${name} = value; };
in
{
  options.pi.core = {
    defaultProvider = nullable types.str null // {
      description = "Pi default provider.";
    };
    defaultModel = nullable types.str null // {
      description = "Pi default model ID.";
    };
    defaultThinkingLevel =
      nullable (types.enum [
        "off"
        "minimal"
        "low"
        "medium"
        "high"
        "xhigh"
      ]) null
      // {
        description = "Default thinking level.";
      };
    hideThinkingBlock = nullable types.bool null // {
      description = "Hide thinking blocks in output.";
    };
    thinkingBudgets = nullable (types.attrsOf types.int) null // {
      description = "Custom token budgets per thinking level.";
    };

    theme = nullable types.str null // {
      description = "Theme name.";
    };
    externalEditor = nullable types.str null // {
      description = "External editor command for Ctrl+G.";
    };
    quietStartup = nullable types.bool null // {
      description = "Hide startup header.";
    };
    defaultProjectTrust =
      nullable (types.enum [
        "ask"
        "always"
        "never"
      ]) null
      // {
        description = "Fallback project trust behavior.";
      };
    collapseChangelog = nullable types.bool null // {
      description = "Show condensed changelog after updates.";
    };
    enableInstallTelemetry = nullable types.bool null // {
      description = "Enable Pi install/update telemetry.";
    };
    enableAnalytics = nullable types.bool null // {
      description = "Enable Pi analytics data sharing.";
    };
    trackingId = nullable types.str null // {
      description = "Pi analytics tracking identifier.";
    };
    doubleEscapeAction =
      nullable (types.enum [
        "tree"
        "fork"
        "none"
      ]) null
      // {
        description = "Action for double escape.";
      };
    treeFilterMode =
      nullable (types.enum [
        "default"
        "no-tools"
        "user-only"
        "labeled-only"
        "all"
      ]) null
      // {
        description = "Default /tree filter mode.";
      };
    editorPaddingX = nullable types.int null // {
      description = "Horizontal editor padding.";
    };
    outputPad = nullable types.int null // {
      description = "Horizontal output padding.";
    };
    autocompleteMaxVisible = nullable types.int null // {
      description = "Autocomplete visible item count.";
    };
    showHardwareCursor = nullable types.bool null // {
      description = "Show terminal hardware cursor.";
    };

    httpProxy = nullable types.str null // {
      description = "Global HTTP proxy URL.";
    };

    warnings.anthropicExtraUsage = nullable types.bool null // {
      description = "Show Anthropic extra-usage warning.";
    };

    compaction = {
      enabled = nullable types.bool null // {
        description = "Enable auto-compaction.";
      };
      reserveTokens = nullable types.int null // {
        description = "Tokens reserved for model response.";
      };
      keepRecentTokens = nullable types.int null // {
        description = "Recent tokens kept before summarization.";
      };
    };

    branchSummary = {
      reserveTokens = nullable types.int null // {
        description = "Tokens reserved for branch summarization.";
      };
      skipPrompt = nullable types.bool null // {
        description = "Skip branch summary prompt on tree navigation.";
      };
    };

    retry = {
      enabled = nullable types.bool null // {
        description = "Enable agent-level retry.";
      };
      maxRetries = nullable types.int null // {
        description = "Agent-level retry count.";
      };
      baseDelayMs = nullable types.int null // {
        description = "Base retry delay in milliseconds.";
      };
      provider.timeoutMs = nullable types.int null // {
        description = "Provider request timeout.";
      };
      provider.maxRetries = nullable types.int null // {
        description = "Provider SDK retry count.";
      };
      provider.maxRetryDelayMs = nullable types.int null // {
        description = "Maximum provider retry delay.";
      };
    };

    steeringMode =
      nullable (types.enum [
        "all"
        "one-at-a-time"
      ]) null
      // {
        description = "How steering messages are delivered.";
      };
    followUpMode =
      nullable (types.enum [
        "all"
        "one-at-a-time"
      ]) null
      // {
        description = "How follow-up messages are delivered.";
      };
    transport =
      nullable (types.enum [
        "sse"
        "websocket"
        "websocket-cached"
        "auto"
      ]) null
      // {
        description = "Preferred provider transport.";
      };
    httpIdleTimeoutMs = nullable types.int null // {
      description = "HTTP stream idle timeout.";
    };
    websocketConnectTimeoutMs = nullable types.int null // {
      description = "WebSocket connect timeout.";
    };

    terminal = {
      showImages = nullable types.bool null // {
        description = "Show images in terminal.";
      };
      imageWidthCells = nullable types.int null // {
        description = "Inline image width in terminal cells.";
      };
      clearOnShrink = nullable types.bool null // {
        description = "Clear rows when content shrinks.";
      };
    };

    images = {
      autoResize = nullable types.bool null // {
        description = "Resize images before sending to model.";
      };
      blockImages = nullable types.bool null // {
        description = "Block images from being sent to the model.";
      };
    };

    shellPath = nullable types.str null // {
      description = "Custom shell path.";
    };
    shellCommandPrefix = nullable types.str null // {
      description = "Prefix added to every bash command.";
    };
    npmCommand = nullable (types.listOf types.str) null // {
      description = "Command argv used for npm package operations.";
    };

    sessionDir = nullable types.str null // {
      description = "Directory for Pi session files.";
    };
    enabledModels = nullable (types.listOf types.str) null // {
      description = "Model patterns for Ctrl+P cycling.";
    };
    markdown.codeBlockIndent = nullable types.str null // {
      description = "Markdown code block indentation.";
    };

    resources = {
      extensions = lib.mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Local extension file paths or directories.";
      };
      skills = lib.mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Local skill file paths or directories.";
      };
      prompts = lib.mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Local prompt template paths or directories.";
      };
      themes = lib.mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Local theme file paths or directories.";
      };
      enableSkillCommands = nullable types.bool null // {
        description = "Register skills as /skill:name commands.";
      };
    };
  };

  config.pi.settings =
    opt "defaultProvider" cfg.defaultProvider
    // opt "defaultModel" cfg.defaultModel
    // opt "defaultThinkingLevel" cfg.defaultThinkingLevel
    // opt "hideThinkingBlock" cfg.hideThinkingBlock
    // opt "thinkingBudgets" cfg.thinkingBudgets
    // opt "theme" cfg.theme
    // opt "externalEditor" cfg.externalEditor
    // opt "quietStartup" cfg.quietStartup
    // opt "defaultProjectTrust" cfg.defaultProjectTrust
    // opt "collapseChangelog" cfg.collapseChangelog
    // opt "enableInstallTelemetry" cfg.enableInstallTelemetry
    // opt "enableAnalytics" cfg.enableAnalytics
    // opt "trackingId" cfg.trackingId
    // opt "doubleEscapeAction" cfg.doubleEscapeAction
    // opt "treeFilterMode" cfg.treeFilterMode
    // opt "editorPaddingX" cfg.editorPaddingX
    // opt "outputPad" cfg.outputPad
    // opt "autocompleteMaxVisible" cfg.autocompleteMaxVisible
    // opt "showHardwareCursor" cfg.showHardwareCursor
    // opt "httpProxy" cfg.httpProxy
    // nested "warnings" {
      anthropicExtraUsage = cfg.warnings.anthropicExtraUsage;
    }
    // nested "compaction" cfg.compaction
    // nested "branchSummary" cfg.branchSummary
    // nested "retry" (clean {
      inherit (cfg.retry) enabled maxRetries baseDelayMs;
      provider = clean cfg.retry.provider;
    })
    // opt "steeringMode" cfg.steeringMode
    // opt "followUpMode" cfg.followUpMode
    // opt "transport" cfg.transport
    // opt "httpIdleTimeoutMs" cfg.httpIdleTimeoutMs
    // opt "websocketConnectTimeoutMs" cfg.websocketConnectTimeoutMs
    // nested "terminal" cfg.terminal
    // nested "images" cfg.images
    // opt "shellPath" cfg.shellPath
    // opt "shellCommandPrefix" cfg.shellCommandPrefix
    // opt "npmCommand" cfg.npmCommand
    // opt "sessionDir" cfg.sessionDir
    // opt "enabledModels" cfg.enabledModels
    // nested "markdown" cfg.markdown
    // lib.optionalAttrs (cfg.resources.extensions != [ ]) { extensions = cfg.resources.extensions; }
    // lib.optionalAttrs (cfg.resources.skills != [ ]) { skills = cfg.resources.skills; }
    // lib.optionalAttrs (cfg.resources.prompts != [ ]) { prompts = cfg.resources.prompts; }
    // lib.optionalAttrs (cfg.resources.themes != [ ]) { themes = cfg.resources.themes; }
    // opt "enableSkillCommands" cfg.resources.enableSkillCommands;
}
