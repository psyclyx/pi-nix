{
  config,
  lib,
  registry ? { },
  ...
}:

let
  packageLib = import ./lib.nix { inherit lib; };
  inherit (lib) types;
  cfg = config.pi.packages.webAccess;
  entry = packageLib.registryEntry registry "web-access";
  providerType = types.enum [
    "auto"
    "openai"
    "brave"
    "parallel"
    "tavily"
    "exa"
    "perplexity"
    "gemini"
  ];
  apiKeys = packageLib.clean {
    openaiApiKey = cfg.apiKeys.openai;
    braveApiKey = cfg.apiKeys.brave;
    exaApiKey = cfg.apiKeys.exa;
    parallelApiKey = cfg.apiKeys.parallel;
    tavilyApiKey = cfg.apiKeys.tavily;
    perplexityApiKey = cfg.apiKeys.perplexity;
    geminiApiKey = cfg.apiKeys.gemini;
    cloudflareApiKey = cfg.apiKeys.cloudflare;
  };
  webAccessConfig =
    apiKeys
    // packageLib.clean {
      inherit (cfg)
        provider
        chromeProfile
        allowBrowserCookies
        searchModel
        summaryModel
        workflow
        curatorTimeoutSeconds
        geminiBaseUrl
        ;
      webSearch = packageLib.clean {
        enabled = cfg.webSearch.enabled;
      };
      githubClone = packageLib.clean cfg.githubClone;
      youtube = packageLib.clean cfg.youtube;
      video = packageLib.clean cfg.video;
      shortcuts = packageLib.clean cfg.shortcuts;
      ssrf = packageLib.clean {
        allowRanges = cfg.ssrf.allowRanges;
      };
    }
    // cfg.extraConfig;
in
{
  options.pi.packages.webAccess =
    packageLib.packageResourceOptions {
      defaultSource = entry.source;
      description = "Pi web search and content access";
    }
    // {
      apiKeys = {
        openai = packageLib.nullable types.str // {
          description = "openaiApiKey. Prefer OPENAI_API_KEY in the environment; this is written into web-search.json.";
        };
        brave = packageLib.nullable types.str // {
          description = "braveApiKey. Prefer BRAVE_API_KEY in the environment.";
        };
        exa = packageLib.nullable types.str // {
          description = "exaApiKey. Prefer EXA_API_KEY in the environment.";
        };
        parallel = packageLib.nullable types.str // {
          description = "parallelApiKey. Prefer PARALLEL_API_KEY in the environment.";
        };
        tavily = packageLib.nullable types.str // {
          description = "tavilyApiKey. Prefer TAVILY_API_KEY in the environment.";
        };
        perplexity = packageLib.nullable types.str // {
          description = "perplexityApiKey. Prefer PERPLEXITY_API_KEY in the environment.";
        };
        gemini = packageLib.nullable types.str // {
          description = "geminiApiKey. Prefer GEMINI_API_KEY in the environment.";
        };
        cloudflare = packageLib.nullable types.str // {
          description = "cloudflareApiKey. Prefer CLOUDFLARE_API_KEY in the environment.";
        };
      };

      provider = packageLib.nullable providerType // {
        description = "Default search provider.";
      };
      chromeProfile = packageLib.nullable types.str // {
        description = "Chromium profile directory for Gemini Web cookie lookup.";
      };
      allowBrowserCookies = packageLib.nullable types.bool // {
        description = "Allow browser cookie extraction for Gemini Web.";
      };
      searchModel = packageLib.nullable types.str // {
        description = "Gemini API model used by web_search.";
      };
      summaryModel = packageLib.nullable types.str // {
        description = "Model used for search summary drafts.";
      };
      workflow =
        packageLib.nullable (
          types.enum [
            "summary-review"
            "auto-summary"
            "none"
          ]
        )
        // {
          description = "Default web_search workflow.";
        };
      curatorTimeoutSeconds = packageLib.nullable types.int // {
        description = "Initial curator idle timeout in seconds.";
      };
      geminiBaseUrl = packageLib.nullable types.str // {
        description = "Gemini API base URL or gateway URL.";
      };

      webSearch.enabled = packageLib.nullable types.bool // {
        description = "Register the web_search tool.";
      };
      githubClone = {
        enabled = packageLib.nullable types.bool // {
          description = "Enable GitHub cloning.";
        };
        maxRepoSizeMB = packageLib.nullable types.int // {
          description = "Maximum GitHub repo size before API fallback.";
        };
        cloneTimeoutSeconds = packageLib.nullable types.int // {
          description = "GitHub clone timeout.";
        };
        clonePath = packageLib.nullable types.str // {
          description = "Directory for cached GitHub clones.";
        };
      };
      youtube = {
        enabled = packageLib.nullable types.bool // {
          description = "Enable YouTube processing.";
        };
        preferredModel = packageLib.nullable types.str // {
          description = "Preferred YouTube Gemini model.";
        };
      };
      video = {
        enabled = packageLib.nullable types.bool // {
          description = "Enable local video processing.";
        };
        preferredModel = packageLib.nullable types.str // {
          description = "Preferred local-video Gemini model.";
        };
        maxSizeMB = packageLib.nullable types.int // {
          description = "Maximum local video upload size.";
        };
      };
      shortcuts = {
        curate = packageLib.nullable types.str // {
          description = "Curator keyboard shortcut.";
        };
        activity = packageLib.nullable types.str // {
          description = "Activity monitor keyboard shortcut.";
        };
      };
      ssrf.allowRanges = packageLib.nullable (types.listOf types.str) // {
        description = "CIDR ranges exempted from the SSRF guard.";
      };
      extraConfig = lib.mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Additional web-search.json fields.";
      };
    };

  config = lib.mkIf cfg.enable {
    pi.packageEntries = [ (packageLib.packageEntry cfg) ];
    pi.files = lib.optionalAttrs (webAccessConfig != { }) {
      "web-search.json" = webAccessConfig;
    };
  };
}
