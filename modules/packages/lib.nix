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
    "${piPackage}/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/${name}";

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
}
