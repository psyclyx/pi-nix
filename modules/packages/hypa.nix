{
  config,
  lib,
  registry ? { },
  ...
}:

let
  packageLib = import ./lib.nix { inherit lib; };
  inherit (lib) types;
  cfg = config.pi.packages.hypa;
  entry = packageLib.registryEntry registry "hypa";
in
{
  options.pi.packages.hypa =
    packageLib.packageResourceOptions {
      defaultSource = entry.source;
      description = "Hypa context runtime integration";
    }
    // {
      binary = packageLib.nullable types.str // {
        description = "HYPA_BIN: Hypa executable or absolute path.";
      };
      mode =
        packageLib.nullable (
          types.enum [
            "additive"
            "replace"
          ]
        )
        // {
          description = "HYPA_PI_MODE: additive keeps Pi builtins; replace disables overlapping Pi builtins.";
        };
      rewriteTimeoutMs = packageLib.nullable types.int // {
        description = "HYPA_PI_REWRITE_TIMEOUT_MS.";
      };
      askNonInteractive =
        packageLib.nullable (
          types.enum [
            "deny"
            "allow"
          ]
        )
        // {
          description = "HYPA_PI_ASK_NON_INTERACTIVE fallback when no UI is available.";
        };
      mcpProxyEnabled = packageLib.nullable types.bool // {
        description = "HYPA_PI_ENABLE_MCP_PROXY.";
      };
      mcpProxyTimeoutMs = packageLib.nullable types.int // {
        description = "HYPA_PI_MCP_PROXY_TIMEOUT_MS.";
      };
      piMcpConfigPath = packageLib.nullable types.str // {
        description = "HYPA_PI_MCP_CONFIG path used to deduplicate Pi MCP servers.";
      };
      configPath = packageLib.nullable types.str // {
        description = "HYPA_PI_CONFIG path. Set to none to skip Hypa config file loading.";
      };
    };

  config = lib.mkIf cfg.enable {
    pi.packageEntries = [ (packageLib.packageEntry cfg) ];
    pi.environment = packageLib.clean {
      HYPA_BIN = cfg.binary;
      HYPA_PI_MODE = cfg.mode;
      HYPA_PI_REWRITE_TIMEOUT_MS =
        if cfg.rewriteTimeoutMs == null then null else toString cfg.rewriteTimeoutMs;
      HYPA_PI_ASK_NON_INTERACTIVE = cfg.askNonInteractive;
      HYPA_PI_ENABLE_MCP_PROXY =
        if cfg.mcpProxyEnabled == null then
          null
        else if cfg.mcpProxyEnabled then
          "1"
        else
          "0";
      HYPA_PI_MCP_PROXY_TIMEOUT_MS =
        if cfg.mcpProxyTimeoutMs == null then null else toString cfg.mcpProxyTimeoutMs;
      HYPA_PI_MCP_CONFIG = cfg.piMcpConfigPath;
      HYPA_PI_CONFIG = cfg.configPath;
    };
  };
}
