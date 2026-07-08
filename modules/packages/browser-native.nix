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
  cfg = config.pi.packages.browserNative;
  entry = packageLib.registryEntry registry "browser-native";
  source = packageLib.npmPackageSource {
    inherit pkgs entry;
    patches = ''
        substituteInPlace "$out/dist/extensions/agent-browser/lib/config-policy.js" \
          --replace-fail 'const includeProjectConfig = options.includeProjectConfig !== false;' \
          'const managedConfigOnly = env.PI_AGENT_BROWSER_MANAGED_CONFIG === "1";
      const includeProjectConfig = options.includeProjectConfig !== false && !managedConfigOnly;'

      substituteInPlace "$out/dist/extensions/agent-browser/lib/config-policy.js" \
        --replace-fail '{ path: paths.global, scope: "global" },' \
        '...(managedConfigOnly ? [] : [{ path: paths.global, scope: "global" }]),'

        substituteInPlace "$out/dist/extensions/agent-browser/lib/config.js" \
          --replace-fail 'const includeProjectConfig = options.includeProjectConfig !== false;' \
          'const managedConfigOnly = env.PI_AGENT_BROWSER_MANAGED_CONFIG === "1";
      const includeProjectConfig = options.includeProjectConfig !== false && !managedConfigOnly;'

      substituteInPlace "$out/dist/extensions/agent-browser/lib/config.js" \
        --replace-fail '{ path: paths.global, scope: "global" },' \
        '...(managedConfigOnly ? [] : [{ path: paths.global, scope: "global" }]),'
    '';
  };
  browserNativeConfig =
    packageLib.clean {
      inherit (cfg) version;
      webSearch = packageLib.clean cfg.webSearch;
      browser = packageLib.clean {
        inherit (cfg.browser)
          defaultLaunchArgs
          executablePath
          ;
        defaultProfile = packageLib.clean cfg.browser.defaultProfile;
      };
    }
    // cfg.extraConfig;
  typedEnvironment = packageLib.clean {
    PI_AGENT_BROWSER_ALLOW_DIRECT_BASH =
      if cfg.allowDirectBash == null then
        null
      else if cfg.allowDirectBash then
        "1"
      else
        "0";
    PI_AGENT_BROWSER_PROCESS_TIMEOUT_MS =
      if cfg.processTimeoutMs == null then null else toString cfg.processTimeoutMs;
    PI_AGENT_BROWSER_DIALOG_PROCESS_TIMEOUT_MS =
      if cfg.dialogProcessTimeoutMs == null then null else toString cfg.dialogProcessTimeoutMs;
    PI_AGENT_BROWSER_DIALOG_TRIGGER_PROCESS_TIMEOUT_MS =
      if cfg.dialogTriggerProcessTimeoutMs == null then
        null
      else
        toString cfg.dialogTriggerProcessTimeoutMs;
    PI_AGENT_BROWSER_IMPLICIT_SESSION_IDLE_TIMEOUT_MS =
      if cfg.implicitSessionIdleTimeoutMs == null then
        null
      else
        toString cfg.implicitSessionIdleTimeoutMs;
    PI_AGENT_BROWSER_IMPLICIT_SESSION_CLOSE_TIMEOUT_MS =
      if cfg.implicitSessionCloseTimeoutMs == null then
        null
      else
        toString cfg.implicitSessionCloseTimeoutMs;
    PI_AGENT_BROWSER_TEMP_ROOT_MAX_BYTES =
      if cfg.tempRootMaxBytes == null then null else toString cfg.tempRootMaxBytes;
    PI_AGENT_BROWSER_SESSION_ARTIFACT_MAX_BYTES =
      if cfg.sessionArtifactMaxBytes == null then null else toString cfg.sessionArtifactMaxBytes;
    PI_AGENT_BROWSER_SESSION_ARTIFACT_MANIFEST_MAX_ENTRIES =
      if cfg.sessionArtifactManifestMaxEntries == null then
        null
      else
        toString cfg.sessionArtifactManifestMaxEntries;
    PI_AGENT_BROWSER_INLINE_IMAGE_MAX_BYTES =
      if cfg.inlineImageMaxBytes == null then null else toString cfg.inlineImageMaxBytes;
  };
in
{
  options.pi.packages.browserNative =
    packageLib.packageResourceOptions {
      defaultSource = source;
      description = "Native agent-browser tool integration for Pi";
    }
    // {
      version = packageLib.nullable (types.enum [ 1 ]) // {
        description = "Config schema version. Upstream currently accepts 1.";
      };
      webSearch = {
        enabled = packageLib.nullable types.bool // {
          description = "webSearch.enabled.";
        };
        preferredProvider =
          packageLib.nullable (
            types.enum [
              "exa"
              "brave"
            ]
          )
          // {
            description = "webSearch.preferredProvider.";
          };
        exaApiKey = packageLib.nullable types.str // {
          description = "webSearch.exaApiKey. Prefer an environment reference like $EXA_API_KEY or a secret command source.";
        };
        braveApiKey = packageLib.nullable types.str // {
          description = "webSearch.braveApiKey. Prefer an environment reference like $BRAVE_API_KEY or a secret command source.";
        };
      };
      browser = {
        defaultProfile = {
          name = packageLib.nullable types.str // {
            description = "browser.defaultProfile.name.";
          };
          policy =
            packageLib.nullable (
              types.enum [
                "explicit-only"
                "authenticated-only"
                "always"
              ]
            )
            // {
              description = "browser.defaultProfile.policy.";
            };
        };
        executablePath = packageLib.nullable types.str // {
          description = "browser.executablePath.";
        };
        defaultLaunchArgs = packageLib.nullable (types.listOf types.str) // {
          description = "browser.defaultLaunchArgs. Upstream records this for future use; current releases do not auto-inject it.";
        };
      };
      allowDirectBash = packageLib.nullable types.bool // {
        description = "PI_AGENT_BROWSER_ALLOW_DIRECT_BASH.";
      };
      processTimeoutMs = packageLib.nullable types.int // {
        description = "PI_AGENT_BROWSER_PROCESS_TIMEOUT_MS.";
      };
      dialogProcessTimeoutMs = packageLib.nullable types.int // {
        description = "PI_AGENT_BROWSER_DIALOG_PROCESS_TIMEOUT_MS.";
      };
      dialogTriggerProcessTimeoutMs = packageLib.nullable types.int // {
        description = "PI_AGENT_BROWSER_DIALOG_TRIGGER_PROCESS_TIMEOUT_MS.";
      };
      implicitSessionIdleTimeoutMs = packageLib.nullable types.int // {
        description = "PI_AGENT_BROWSER_IMPLICIT_SESSION_IDLE_TIMEOUT_MS.";
      };
      implicitSessionCloseTimeoutMs = packageLib.nullable types.int // {
        description = "PI_AGENT_BROWSER_IMPLICIT_SESSION_CLOSE_TIMEOUT_MS.";
      };
      tempRootMaxBytes = packageLib.nullable types.int // {
        description = "PI_AGENT_BROWSER_TEMP_ROOT_MAX_BYTES.";
      };
      sessionArtifactMaxBytes = packageLib.nullable types.int // {
        description = "PI_AGENT_BROWSER_SESSION_ARTIFACT_MAX_BYTES.";
      };
      sessionArtifactManifestMaxEntries = packageLib.nullable types.int // {
        description = "PI_AGENT_BROWSER_SESSION_ARTIFACT_MANIFEST_MAX_ENTRIES.";
      };
      inlineImageMaxBytes = packageLib.nullable types.int // {
        description = "PI_AGENT_BROWSER_INLINE_IMAGE_MAX_BYTES.";
      };
      agentBrowserPackage = packageLib.nullable types.package // {
        description = "Optional Nix package that provides the agent-browser executable on PATH.";
      };
      environment = lib.mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Raw pi-agent-browser-native or upstream agent-browser environment overrides.";
      };
      extraConfig = lib.mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Additional pi-agent-browser-native config fields.";
      };
    };

  config = lib.mkIf cfg.enable {
    pi.packageEntries = [ (packageLib.packageEntry cfg) ];
    pi.files."config/pi-agent-browser-native/config.json" = browserNativeConfig;
    pi.agentDirEnvironment.PI_AGENT_BROWSER_CONFIG = "config/pi-agent-browser-native/config.json";
    pi.environment = {
      PI_AGENT_BROWSER_MANAGED_CONFIG = "1";
    }
    // typedEnvironment
    // cfg.environment;
    pi.extraPackages = lib.optional (cfg.agentBrowserPackage != null) cfg.agentBrowserPackage;
  };
}
