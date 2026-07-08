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
  cfg = config.pi.packages.statusline;
  entry = packageLib.registryEntry registry "statusline";
  source = packageLib.npmPackageSource {
    inherit pkgs entry;
    patches = ''
      substituteInPlace "$out/src/statusline.ts" \
        --replace-fail 'palette: "candy",' 'palette: readStatuslinePalette(),'

      substituteInPlace "$out/src/statusline.ts" \
        --replace-fail 'density: "compact",' 'density: readStatuslineDensity(),'

      substituteInPlace "$out/src/statusline.ts" \
        --replace-fail 'separator: "dot",' 'separator: readStatuslineSeparator(),'

      substituteInPlace "$out/src/statusline.ts" \
        --replace-fail 'showLabels: false,' 'showLabels: readStatuslineShowLabels(),'

      substituteInPlace "$out/src/statusline.ts" \
        --replace-fail 'segments: [...DEFAULT_SEGMENTS],' 'segments: readStatuslineSegments(),'

      substituteInPlace "$out/src/statusline.ts" \
        --replace-fail 'function readStatuslinePreset(): StatuslinePresetName {' \
        $'function readStatuslinePalette(): PaletteName {\n\tconst value = process.env.PI_STATUSLINE_PALETTE?.trim().toLowerCase();\n\tif (value === "ocean" || value === "sunset" || value === "forest" || value === "candy" || value === "neon" || value === "mono") return value;\n\treturn "candy";\n}\n\nfunction readStatuslineDensity(): Density {\n\tconst value = process.env.PI_STATUSLINE_DENSITY?.trim().toLowerCase();\n\tif (value === "compact" || value === "cozy") return value;\n\treturn "compact";\n}\n\nfunction readStatuslineSeparator(): SeparatorName {\n\tconst value = process.env.PI_STATUSLINE_SEPARATOR?.trim().toLowerCase();\n\tif (value === "dot" || value === "bar" || value === "powerline" || value === "round" || value === "none") return value;\n\treturn "dot";\n}\n\nfunction readStatuslineShowLabels(): boolean {\n\tconst value = process.env.PI_STATUSLINE_SHOW_LABELS?.trim().toLowerCase();\n\treturn value === "1" || value === "true" || value === "yes";\n}\n\nfunction readStatuslineSegments(): SegmentName[] {\n\tconst raw = process.env.PI_STATUSLINE_SEGMENTS?.trim();\n\tif (!raw) return [...DEFAULT_SEGMENTS];\n\tconst allowed = new Set<SegmentName>(["brand", "model", "thinking", "cwd", "branch", "tools", "context", "tokens", "cost", "time", "turn"]);\n\tconst segments = raw.split(",").map((segment) => segment.trim()).filter((segment): segment is SegmentName => allowed.has(segment as SegmentName));\n\treturn segments.length > 0 ? segments : [...DEFAULT_SEGMENTS];\n}\n\nfunction readStatuslinePreset(): StatuslinePresetName {'

      substituteInPlace "$out/src/statusline.ts" \
        --replace-fail $'function findDuplicateExtensions(cwd: string): string[] {\n\tconst settingsFiles = [\n\t\tjoin(process.env.HOME ?? "", ".pi", "agent", "settings.json"),\n\t\tjoin(cwd, ".pi", "settings.json"),\n\t].filter((file) => existsSync(file));' \
        $'function findDuplicateExtensions(cwd: string): string[] {\n\tconst scanUser = process.env.PI_STATUSLINE_SCAN_USER_CONFIG === "1";\n\tconst scanProject = process.env.PI_STATUSLINE_SCAN_PROJECT_CONFIG === "1";\n\tconst settingsFiles = [\n\t\t...(scanUser ? [join(process.env.HOME ?? "", ".pi", "agent", "settings.json")] : []),\n\t\t...(scanProject ? [join(cwd, ".pi", "settings.json")] : []),\n\t].filter((file) => existsSync(file));'
    '';
  };

  enum = values: packageLib.nullable (types.enum values);
  typedEnvironment = packageLib.clean {
    PI_STATUSLINE_PRESET = cfg.preset;
    PI_STATUSLINE_PALETTE = cfg.palette;
    PI_STATUSLINE_DENSITY = cfg.density;
    PI_STATUSLINE_SEPARATOR = cfg.separator;
    PI_STATUSLINE_SHOW_LABELS =
      if cfg.showLabels == null then
        null
      else if cfg.showLabels then
        "1"
      else
        "0";
    PI_STATUSLINE_SEGMENTS =
      if cfg.segments == null then null else lib.concatStringsSep "," cfg.segments;
    PI_STATUSLINE_SCAN_USER_CONFIG = if cfg.scanUserConfig then "1" else "0";
    PI_STATUSLINE_SCAN_PROJECT_CONFIG = if cfg.scanProjectConfig then "1" else "0";
  };
in
{
  options.pi.packages.statusline =
    packageLib.packageResourceOptions {
      defaultSource = source;
      description = "Information-rich Pi footer statusline";
    }
    // {
      preset =
        enum [
          "classic"
          "tokyo-night"
        ]
        // {
          description = "Statusline rendering preset.";
        };
      palette =
        enum [
          "ocean"
          "sunset"
          "forest"
          "candy"
          "neon"
          "mono"
        ]
        // {
          description = "Classic statusline color palette.";
        };
      density =
        enum [
          "compact"
          "cozy"
        ]
        // {
          description = "Statusline spacing density.";
        };
      separator =
        enum [
          "dot"
          "bar"
          "powerline"
          "round"
          "none"
        ]
        // {
          description = "Classic statusline separator style.";
        };
      showLabels = packageLib.nullable types.bool // {
        description = "Whether statusline segments should show labels.";
      };
      segments =
        packageLib.nullable (
          types.listOf (
            types.enum [
              "brand"
              "model"
              "thinking"
              "cwd"
              "branch"
              "tools"
              "context"
              "tokens"
              "cost"
              "time"
              "turn"
            ]
          )
        )
        // {
          description = "Ordered statusline segments.";
        };
      extensionStatusIcons = lib.mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Per-extension status icon overrides.";
      };
      scanUserConfig = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Read the normal user ~/.pi/agent/settings.json when looking for duplicate package sources.";
      };
      scanProjectConfig = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Read project .pi/settings.json when looking for duplicate package sources.";
      };
      environment = lib.mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Raw pi-statusline environment overrides.";
      };
    };

  config = lib.mkIf cfg.enable {
    pi.packageEntries = [ (packageLib.packageEntry cfg) ];
    pi.files."pi-statusline-settings.json" = {
      inherit (cfg) extensionStatusIcons;
    };
    pi.environment = typedEnvironment // cfg.environment;
  };
}
