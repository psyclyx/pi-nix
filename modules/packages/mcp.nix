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
  cfg = config.pi.packages.mcp;
  entry = packageLib.registryEntry registry "mcp";

  directToolsType = types.either types.bool (types.listOf types.str);
  outputGuardType = types.either types.bool (
    types.submodule {
      options = {
        maxBytes = packageLib.nullable types.int // {
          description = "Maximum inline text bytes.";
        };
        maxLines = packageLib.nullable types.int // {
          description = "Maximum inline text lines.";
        };
        detailsMaxBytes = packageLib.nullable types.int // {
          description = "Maximum raw mcpResult detail bytes.";
        };
      };
    }
  );

  serverModule =
    { ... }:
    {
      options = {
        command = packageLib.nullable types.str // {
          description = "Executable for stdio MCP transport.";
        };
        args = lib.mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Command arguments.";
        };
        env = lib.mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = "Environment variables for the MCP server.";
        };
        cwd = packageLib.nullable types.str // {
          description = "Working directory for the MCP server.";
        };
        url = packageLib.nullable types.str // {
          description = "HTTP MCP endpoint.";
        };
        headers = lib.mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = "HTTP headers for remote MCP servers.";
        };
        auth =
          packageLib.nullable (
            types.enum [
              "bearer"
              "oauth"
            ]
          )
          // {
            description = "Remote MCP auth mode.";
          };
        oauth = {
          grantType =
            packageLib.nullable (
              types.enum [
                "authorization_code"
                "client_credentials"
              ]
            )
            // {
              description = "OAuth grant type.";
            };
          clientId = packageLib.nullable types.str // {
            description = "OAuth client id.";
          };
          clientSecret = packageLib.nullable types.str // {
            description = "OAuth client secret. Prefer environment interpolation.";
          };
          scope = packageLib.nullable types.str // {
            description = "OAuth scope.";
          };
          redirectUri = packageLib.nullable types.str // {
            description = "Exact OAuth redirect URI.";
          };
          clientName = packageLib.nullable types.str // {
            description = "Dynamic OAuth client display name.";
          };
          clientUri = packageLib.nullable types.str // {
            description = "Dynamic OAuth client homepage URI.";
          };
        };
        bearerToken = packageLib.nullable types.str // {
          description = "Bearer token. Prefer bearerTokenEnv or environment interpolation.";
        };
        bearerTokenEnv = packageLib.nullable types.str // {
          description = "Environment variable containing the bearer token.";
        };
        lifecycle =
          packageLib.nullable (
            types.enum [
              "lazy"
              "eager"
              "keep-alive"
            ]
          )
          // {
            description = "MCP server lifecycle mode.";
          };
        idleTimeout = packageLib.nullable types.int // {
          description = "Idle disconnect timeout in minutes.";
        };
        requestTimeoutMs = packageLib.nullable types.int // {
          description = "Live MCP call timeout.";
        };
        exposeResources = packageLib.nullable types.bool // {
          description = "Expose MCP resources as tools.";
        };
        directTools = packageLib.nullable directToolsType // {
          description = "Direct-tool exposure: true, false, or a list of tool names.";
        };
        excludeTools = lib.mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "MCP tools to hide.";
        };
        debug = packageLib.nullable types.bool // {
          description = "Show server stderr.";
        };
        extraConfig = lib.mkOption {
          type = types.attrsOf types.anything;
          default = { };
          description = "Additional server fields.";
        };
      };
    };

  cleanServer =
    server:
    packageLib.clean {
      inherit (server)
        command
        cwd
        url
        auth
        bearerToken
        bearerTokenEnv
        lifecycle
        idleTimeout
        requestTimeoutMs
        exposeResources
        directTools
        debug
        ;
      args = if server.args == [ ] then null else server.args;
      env = if server.env == { } then null else server.env;
      headers = if server.headers == { } then null else server.headers;
      excludeTools = if server.excludeTools == [ ] then null else server.excludeTools;
      oauth = packageLib.clean server.oauth;
    }
    // server.extraConfig;

  mcpConfig =
    packageLib.clean {
      imports = if cfg.imports == [ ] then null else cfg.imports;
      settings = packageLib.clean {
        inherit (cfg.settings)
          toolPrefix
          idleTimeout
          requestTimeoutMs
          directTools
          disableProxyTool
          autoAuth
          sampling
          samplingAutoApprove
          elicitation
          outputGuard
          ;
      };
      mcpServers = if cfg.servers == { } then null else lib.mapAttrs (_: cleanServer) cfg.servers;
    }
    // cfg.extraConfig;
in
{
  options.pi.packages.mcp =
    packageLib.packageResourceOptions {
      defaultSource = packageLib.packageSource {
        inherit pkgs registry entry;
        piPackage = config.pi.package;
      };
      description = "MCP adapter for Pi";
    }
    // {
      imports = lib.mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Host-specific MCP config imports, such as cursor, claude-code, vscode, windsurf, or codex.";
      };

      servers = lib.mkOption {
        type = types.attrsOf (types.submodule serverModule);
        default = { };
        description = "MCP servers written to mcp.json.";
      };

      settings = {
        toolPrefix =
          packageLib.nullable (
            types.enum [
              "server"
              "short"
              "none"
            ]
          )
          // {
            description = "MCP direct/proxy tool prefix mode.";
          };
        idleTimeout = packageLib.nullable types.int // {
          description = "Global idle timeout in minutes.";
        };
        requestTimeoutMs = packageLib.nullable types.int // {
          description = "Global live MCP request timeout.";
        };
        directTools = packageLib.nullable directToolsType // {
          description = "Global direct-tool default.";
        };
        disableProxyTool = packageLib.nullable types.bool // {
          description = "Hide the mcp proxy tool once direct tools are available.";
        };
        autoAuth = packageLib.nullable types.bool // {
          description = "Automatically run OAuth for servers that need auth.";
        };
        sampling = packageLib.nullable types.bool // {
          description = "Allow MCP servers to sample through Pi models.";
        };
        samplingAutoApprove = packageLib.nullable types.bool // {
          description = "Skip MCP sampling confirmation prompts.";
        };
        elicitation = packageLib.nullable types.bool // {
          description = "Allow MCP servers to request user input through Pi dialogs.";
        };
        outputGuard = packageLib.nullable outputGuardType // {
          description = "MCP output guard configuration.";
        };
      };

      extraConfig = lib.mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Additional mcp.json fields.";
      };
    };

  config = lib.mkIf cfg.enable {
    pi.packageEntries = lib.mkOrder 120 [ (packageLib.packageEntry cfg) ];
    pi.files = lib.optionalAttrs (mcpConfig != { }) {
      "mcp.json" = mcpConfig;
    };
  };
}
