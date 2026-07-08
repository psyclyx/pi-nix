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
  cfg = config.pi.packages.hermesMemory;
  entry = packageLib.registryEntry registry "hermes-memory";
  source = packageLib.npmPackageSource { inherit pkgs entry; };
  memoryConfig =
    packageLib.clean {
      inherit (cfg)
        autoConsolidate
        consolidationTimeoutMs
        correctionDetection
        correctionDirectiveWords
        correctionNegativePatterns
        correctionStrongPatterns
        correctionWeakPatterns
        failureInjectionEnabled
        failureInjectionMaxAgeDays
        failureInjectionMaxEntries
        flushMinTurns
        flushOnCompact
        flushOnShutdown
        flushRecentMessages
        llmModelOverride
        llmThinkingOverride
        memoryCharLimit
        memoryDir
        memoryMode
        memoryOverflowStrategy
        memoryPolicyCustomText
        memoryPolicyStyle
        nudgeInterval
        nudgeToolCalls
        projectCharLimit
        projectsMemoryDir
        reviewEnabled
        reviewRecentMessages
        reviewTransport
        userCharLimit
        ;
      sessionSearch = packageLib.clean cfg.sessionSearch;
    }
    // cfg.extraConfig;
in
{
  options.pi.packages.hermesMemory =
    packageLib.packageResourceOptions {
      defaultSource = source;
      description = "Hermes persistent memory and session search for Pi";
    }
    // {
      memoryMode =
        packageLib.nullable (
          types.enum [
            "policy-only"
            "legacy-inject"
          ]
        )
        // {
          description = "memoryMode.";
        };
      memoryPolicyStyle =
        packageLib.nullable (
          types.enum [
            "full"
            "compact"
            "custom"
            "none"
          ]
        )
        // {
          description = "memoryPolicyStyle.";
        };
      memoryPolicyCustomText = packageLib.nullable types.str // {
        description = "memoryPolicyCustomText.";
      };
      memoryCharLimit = packageLib.nullable types.int // {
        description = "memoryCharLimit.";
      };
      userCharLimit = packageLib.nullable types.int // {
        description = "userCharLimit.";
      };
      projectCharLimit = packageLib.nullable types.int // {
        description = "projectCharLimit.";
      };
      nudgeInterval = packageLib.nullable types.int // {
        description = "nudgeInterval.";
      };
      nudgeToolCalls = packageLib.nullable types.int // {
        description = "nudgeToolCalls.";
      };
      reviewRecentMessages = packageLib.nullable types.int // {
        description = "reviewRecentMessages.";
      };
      reviewEnabled = packageLib.nullable types.bool // {
        description = "reviewEnabled.";
      };
      reviewTransport =
        packageLib.nullable (
          types.enum [
            "direct"
            "subprocess"
          ]
        )
        // {
          description = "reviewTransport.";
        };
      flushOnCompact = packageLib.nullable types.bool // {
        description = "flushOnCompact.";
      };
      flushOnShutdown = packageLib.nullable types.bool // {
        description = "flushOnShutdown.";
      };
      flushMinTurns = packageLib.nullable types.int // {
        description = "flushMinTurns.";
      };
      flushRecentMessages = packageLib.nullable types.int // {
        description = "flushRecentMessages.";
      };
      autoConsolidate = packageLib.nullable types.bool // {
        description = "autoConsolidate legacy compatibility flag.";
      };
      memoryOverflowStrategy =
        packageLib.nullable (
          types.enum [
            "auto-consolidate"
            "reject"
            "fifo-evict"
          ]
        )
        // {
          description = "memoryOverflowStrategy.";
        };
      correctionDetection = packageLib.nullable types.bool // {
        description = "correctionDetection.";
      };
      correctionStrongPatterns = packageLib.nullable (types.listOf types.str) // {
        description = "correctionStrongPatterns.";
      };
      correctionWeakPatterns = packageLib.nullable (types.listOf types.str) // {
        description = "correctionWeakPatterns.";
      };
      correctionNegativePatterns = packageLib.nullable (types.listOf types.str) // {
        description = "correctionNegativePatterns.";
      };
      correctionDirectiveWords = packageLib.nullable (types.listOf types.str) // {
        description = "correctionDirectiveWords.";
      };
      consolidationTimeoutMs = packageLib.nullable types.int // {
        description = "consolidationTimeoutMs.";
      };
      failureInjectionEnabled = packageLib.nullable types.bool // {
        description = "failureInjectionEnabled.";
      };
      failureInjectionMaxAgeDays = packageLib.nullable types.int // {
        description = "failureInjectionMaxAgeDays.";
      };
      failureInjectionMaxEntries = packageLib.nullable types.int // {
        description = "failureInjectionMaxEntries.";
      };
      memoryDir = packageLib.nullable types.str // {
        description = "memoryDir. Relative paths are resolved under PI_CODING_AGENT_DIR by Hermes.";
      };
      projectsMemoryDir = packageLib.nullable types.str // {
        description = "projectsMemoryDir. Hermes accepts a single safe relative directory under PI_CODING_AGENT_DIR.";
      };
      sessionSearch.variant =
        packageLib.nullable (
          types.enum [
            "legacy"
            "anchors"
          ]
        )
        // {
          description = "sessionSearch.variant.";
        };
      llmModelOverride = packageLib.nullable types.str // {
        description = "llmModelOverride.";
      };
      llmThinkingOverride =
        packageLib.nullable (
          types.enum [
            "off"
            "minimal"
            "low"
            "medium"
            "high"
            "xhigh"
          ]
        )
        // {
          description = "llmThinkingOverride.";
        };
      extraConfig = lib.mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Additional hermes-memory-config.json fields.";
      };
    };

  config = lib.mkIf cfg.enable {
    pi.packageEntries = [ (packageLib.packageEntry cfg) ];
    pi.files = lib.optionalAttrs (memoryConfig != { }) {
      "hermes-memory-config.json" = memoryConfig;
    };
  };
}
