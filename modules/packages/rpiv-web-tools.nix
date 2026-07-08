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
  cfg = config.pi.packages.rpivWebTools;
  entry = packageLib.registryEntry registry "rpiv-web-tools";
  piPeer = packageLib.piPackageNodeModule (piPackages.pi or config.pi.package);
  typebox = piPeer "typebox";
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
      inherit typebox;
      "@juicesharp/rpiv-config" = rpivConfig;
    };
    patches = ''
      substituteInPlace "$out/providers/config.ts" \
        --replace-fail 'const CONFIG_PATH = configPath("rpiv-web-tools");' \
        'const CONFIG_PATH = process.env.RPIV_WEB_TOOLS_CONFIG_PATH?.trim() || configPath("rpiv-web-tools");'
    '';
  };
  providerNames = [
    "brave"
    "tavily"
    "serper"
    "exa"
    "youcom"
    "jina"
    "firecrawl"
    "perplexity"
    "searxng"
    "ollama"
  ];
  guidanceType = types.submodule {
    options = {
      promptSnippet = packageLib.nullable types.str // {
        description = "Tool prompt snippet.";
      };
      promptGuidelines = packageLib.nullable (types.listOf types.str) // {
        description = "Tool prompt guidelines.";
      };
    };
  };
  githubInterceptorType = types.either types.bool (
    types.submodule {
      options = {
        enabled = packageLib.nullable types.bool // {
          description = "Enable the GitHub URL interceptor.";
        };
        maxRepoSizeMB = packageLib.nullable types.int // {
          description = "Maximum repository size to clone through the GitHub interceptor.";
        };
        cloneTimeoutSeconds = packageLib.nullable types.int // {
          description = "GitHub clone timeout in seconds.";
        };
        clonePath = packageLib.nullable types.str // {
          description = "Directory used for cached GitHub clones.";
        };
      };
    }
  );
  webToolsConfig =
    packageLib.clean {
      inherit (cfg)
        provider
        baseUrls
        ;
      guidance = packageLib.clean cfg.guidance;
      interceptors = packageLib.clean {
        inherit (cfg.interceptors) github;
      };
    }
    // cfg.extraConfig;
in
{
  options.pi.packages.rpivWebTools =
    packageLib.packageResourceOptions {
      defaultSource = source;
      description = "RPiV web search and fetch tools";
    }
    // {
      provider = packageLib.nullable (types.enum providerNames) // {
        description = "Active web provider. API keys should be provided by environment variables or auth-managed files.";
      };
      baseUrls = lib.mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Per-provider base URL overrides, such as searxng or ollama.";
      };
      guidance = {
        web_search = packageLib.nullable guidanceType // {
          description = "web_search guidance override.";
        };
        web_fetch = packageLib.nullable guidanceType // {
          description = "web_fetch guidance override.";
        };
      };
      interceptors.github = packageLib.nullable githubInterceptorType // {
        description = "GitHub URL interceptor config.";
      };
      extraConfig = lib.mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Additional rpiv-web-tools config fields.";
      };
      environment = lib.mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Raw rpiv-web-tools environment overrides, including provider API-key variables.";
      };
    };

  config = lib.mkIf cfg.enable {
    pi.packageEntries = [ (packageLib.packageEntry cfg) ];
    pi.files."config/rpiv-web-tools/config.json" = webToolsConfig;
    pi.agentDirEnvironment.RPIV_WEB_TOOLS_CONFIG_PATH = "config/rpiv-web-tools/config.json";
    pi.environment = cfg.environment;
  };
}
