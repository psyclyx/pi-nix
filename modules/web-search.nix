{ config, lib, ... }:

let
  inherit (lib) types;
  cfg = config.pi.webSearch;

  providers = {
    openai = {
      env = "OPENAI_API_KEY";
      setting = "openaiApiKey";
    };
    brave = {
      env = "BRAVE_API_KEY";
      setting = "braveApiKey";
    };
    parallel = {
      env = "PARALLEL_API_KEY";
      setting = "parallelApiKey";
    };
    tavily = {
      env = "TAVILY_API_KEY";
      setting = "tavilyApiKey";
    };
    exa = {
      env = "EXA_API_KEY";
      setting = "exaApiKey";
    };
    gemini = {
      env = "GEMINI_API_KEY";
      setting = "geminiApiKey";
    };
    perplexity = {
      env = "PERPLEXITY_API_KEY";
      setting = "perplexityApiKey";
    };
    cloudflare = {
      env = "CLOUDFLARE_API_KEY";
      setting = "cloudflareApiKey";
    };
  };

  configuredKeyFiles = lib.filterAttrs (_: value: value != null) cfg.keyFiles;
  environmentFiles = lib.mapAttrs' (
    name: path: lib.nameValuePair providers.${name}.env path
  ) configuredKeyFiles;

  secretSettingNames = lib.mapAttrs' (
    _: provider: lib.nameValuePair provider.setting true
  ) providers;
  hasWebSearchConfig = cfg.settings != { } || configuredKeyFiles != { };
in
{
  options.pi.webSearch = {
    settings = lib.mkOption {
      type = types.attrsOf types.anything;
      default = { };
      apply =
        value:
        let
          secretSettings = lib.attrNames (builtins.intersectAttrs secretSettingNames value);
        in
        if secretSettings != [ ] then
          lib.warn ''
            pi.webSearch.settings contains secret field(s): ${lib.concatStringsSep ", " secretSettings}.
            Prefer pi.webSearch.keyFiles so provider keys stay out of the Nix store.
          '' value
        else
          value;
      example = lib.literalExpression ''
        {
          provider = "exa";
          workflow = "none";
          webSearch.enabled = true;
          allowBrowserCookies = false;
        }
      '';
      description = ''
        Non-secret pi-web-access configuration written to web-search.json.
        API keys here trigger an evaluation warning; prefer pi.webSearch.keyFiles
        so secrets stay out of the Nix store.
      '';
    };

    keyFiles = lib.mkOption {
      type = types.submodule {
        options = lib.mapAttrs (
          name: provider:
          lib.mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Runtime file containing the ${name} provider key exported as ${provider.env}.";
          }
        ) providers;
      };
      default = { };
      description = ''
        Runtime files containing pi-web-access provider API keys. The launcher
        reads these files at startup and exports the provider environment
        variables consumed by pi-web-access.
      '';
    };

    enablePackage = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Whether pi.webSearch configuration enables the web-access registry package by default.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.settings != { }) {
      pi.files."web-search.json" = cfg.settings;
    })

    (lib.mkIf (configuredKeyFiles != { }) {
      pi.environmentFiles = environmentFiles;
    })

    (lib.mkIf (cfg.enablePackage && hasWebSearchConfig) {
      pi.packages.registry.web-access.enable = lib.mkDefault true;
    })
  ];
}
