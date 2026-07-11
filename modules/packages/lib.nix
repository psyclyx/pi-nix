{ lib }:

let
  inherit (lib) types;
  sourceType = types.either types.str types.path;
  sourceToString = value: if builtins.isPath value then toString value else value;
in
rec {
  inherit sourceType sourceToString;

  piPackageNodeModule =
    piPackage: name:
    if name == "@earendil-works/pi-coding-agent" then
      "${piPackage}/lib/node_modules/@earendil-works/pi-coding-agent"
    else
      "${piPackage}/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/${name}";

  isBundledPiNodeModule = name: lib.hasPrefix "@earendil-works/pi-" name;
  piDependencyAliasPrefix = "pi:";
  isPiDependencyAlias = alias: lib.hasPrefix piDependencyAliasPrefix alias;

  registryEntry =
    registry: name:
    let
      entries = registry.piPackages or { };
    in
    entries.${name} or (throw "pi-nix: registry.piPackages.${name} is required");

  npmRegistryEntry =
    registry: name:
    let
      entries = registry.npmPackages or { };
    in
    entries.${name} or (throw "pi-nix: registry.npmPackages.${name} is required");

  nullable =
    type:
    lib.mkOption {
      type = types.nullOr type;
      default = null;
    };

  clean =
    attrs:
    lib.filterAttrs (_: value: value != null && value != { }) (
      lib.mapAttrs (_: value: if builtins.isAttrs value then clean value else value) attrs
    );

  packageResourceOptions =
    {
      defaultSource,
      description,
    }:
    {
      enable = lib.mkEnableOption description;

      source = lib.mkOption {
        type = sourceType;
        default = defaultSource;
        description = "Pi package source written to settings.json.";
      };

      developmentPath = nullable sourceType // {
        description = "Local package directory to use instead of source while iterating.";
      };

      autoload = nullable types.bool // {
        description = "Pi package autoload override.";
      };

      extensions = nullable (types.listOf types.str) // {
        description = "Extension resource filters for this package. Null loads package defaults; [] loads none.";
      };

      skills = nullable (types.listOf types.str) // {
        description = "Skill resource filters for this package. Null loads package defaults; [] loads none.";
      };

      prompts = nullable (types.listOf types.str) // {
        description = "Prompt resource filters for this package. Null loads package defaults; [] loads none.";
      };

      themes = nullable (types.listOf types.str) // {
        description = "Theme resource filters for this package. Null loads package defaults; [] loads none.";
      };
    };

  # Per-package config passthrough shared by registry and custom packages.
  # Lets a package carry its own settings.json fields, sidecar JSON files, and
  # environment variables at its definition site instead of forcing the user to
  # hand-write them into the global pi.settings / pi.files / pi.environment.
  packageConfigOptions = {
    settings = lib.mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Additional settings.json fields contributed by this package.";
    };

    files = lib.mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "JSON files written under PI_CODING_AGENT_DIR for this package (e.g. mcp.json, web-search.json).";
    };

    environment = lib.mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Environment variables exported by the generated wrapper for this package.";
    };
  };

  # Merge the packageConfigOptions of a set of enabled packages into the
  # corresponding global pi.* option definitions.
  mergePackageConfig = enabled: {
    pi.settings = lib.mkMerge (lib.mapAttrsToList (_: cfg: cfg.settings) enabled);
    pi.files = lib.mkMerge (lib.mapAttrsToList (_: cfg: cfg.files) enabled);
    pi.environment = lib.mkMerge (lib.mapAttrsToList (_: cfg: cfg.environment) enabled);
  };

  packageEntry =
    cfg:
    clean {
      source = sourceToString (if cfg.developmentPath != null then cfg.developmentPath else cfg.source);
      inherit (cfg)
        autoload
        extensions
        skills
        prompts
        themes
        ;
    };

  npmPackageSource =
    {
      pkgs,
      entry,
      patches ? "",
      nodeModules ? { },
    }:
    let
      packageName = entry.npmPackage or entry.module or "pi-package";
      safeName =
        builtins.replaceStrings
          [
            "@"
            "/"
          ]
          [
            ""
            "-"
          ]
          packageName;
      source = pkgs.fetchzip {
        name = "${safeName}-${entry.version or "unknown"}-source";
        url = entry.tarball or (throw "pi-nix: registry entry for ${packageName} must include tarball");
        hash =
          entry.unpackHash or (throw "pi-nix: registry entry for ${packageName} must include unpackHash");
      };
      linkNodeModuleCommands = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: target:
          let
            parts = lib.splitString "/" name;
            parent = if builtins.length parts > 1 then lib.concatStringsSep "/" (lib.init parts) else ".";
          in
          ''
            mkdir -p "$out/node_modules"/${lib.escapeShellArg parent}
            ln -s ${lib.escapeShellArg (toString target)} "$out/node_modules"/${lib.escapeShellArg name}
          ''
        ) nodeModules
      );
      prepared =
        if patches == "" && nodeModules == { } then
          source
        else
          pkgs.runCommand "${safeName}-${entry.version or "unknown"}-source" { } ''
            mkdir -p "$out"
            cp -R ${source}/. "$out"/
            chmod -R u+w "$out"
            ${patches}
            ${linkNodeModuleCommands}
          '';
    in
    "${prepared}";

  nodeModuleSources =
    {
      pkgs,
      registry,
      dependencies,
      piPackage ? null,
    }:
    lib.mapAttrs (
      nodeModuleName: registryAlias:
      if isPiDependencyAlias registryAlias then
        if piPackage == null then
          throw "pi-nix: ${nodeModuleName} is bundled with Pi, but no piPackage was provided"
        else
          piPackageNodeModule piPackage (lib.removePrefix piDependencyAliasPrefix registryAlias)
      else if isBundledPiNodeModule nodeModuleName then
        if piPackage == null then
          throw "pi-nix: ${nodeModuleName} is bundled with Pi, but no piPackage was provided"
        else
          piPackageNodeModule piPackage nodeModuleName
      else
        npmArtifactSource {
          inherit pkgs registry piPackage;
          alias = registryAlias;
        }
    ) dependencies;

  npmArtifactSource =
    {
      pkgs,
      registry,
      alias,
      piPackage ? null,
    }:
    let
      entry = npmRegistryEntry registry alias;
    in
    npmPackageSource {
      inherit pkgs entry;
      nodeModules = nodeModuleSources {
        inherit pkgs registry piPackage;
        dependencies = entry.dependencies or { };
      };
    };

  packageSource =
    {
      pkgs,
      registry,
      entry,
      piPackage ? null,
      patches ? "",
    }:
    npmPackageSource {
      inherit pkgs entry patches;
      nodeModules = nodeModuleSources {
        inherit pkgs registry piPackage;
        dependencies = entry.nodeModuleDependencies or { };
      };
    };
}
