{
  config,
  lib,
  registry ? { },
  ...
}:

let
  packageLib = import ./lib.nix { inherit lib; };
  inherit (lib) types;
  cfg = config.pi.packages.permissionSystem;
  entry = packageLib.registryEntry registry "permission-system";

  permissionConfig =
    packageLib.clean {
      "$schema" = cfg.schema;
      inherit (cfg)
        debugLog
        permissionReviewLog
        yoloMode
        toolInputPreviewMaxLength
        toolTextSummaryMaxLength
        piInfrastructureReadPaths
        permission
        ;
    }
    // cfg.extraConfig;
in
{
  options.pi.packages.permissionSystem =
    packageLib.packageResourceOptions {
      defaultSource = entry.source;
      description = "Pi permission enforcement";
    }
    // {
      schema = packageLib.nullable types.str // {
        description = "JSON Schema URI for editor autocomplete.";
      };
      debugLog = packageLib.nullable types.bool // {
        description = "Write verbose permission-system diagnostics.";
      };
      permissionReviewLog = packageLib.nullable types.bool // {
        description = "Write permission request and decision audit events.";
      };
      yoloMode = packageLib.nullable types.bool // {
        description = "Auto-approve ask-state permission checks. Use with caution.";
      };
      toolInputPreviewMaxLength = packageLib.nullable types.int // {
        description = "Maximum character length of inline JSON input previews.";
      };
      toolTextSummaryMaxLength = packageLib.nullable types.int // {
        description = "Maximum character length of inline pattern/path summaries.";
      };
      piInfrastructureReadPaths = packageLib.nullable (types.listOf types.str) // {
        description = "Extra directories auto-allowed for reads as Pi infrastructure.";
      };
      permission = lib.mkOption {
        type = types.attrsOf types.anything;
        default = {
          "*" = "ask";
          path = {
            "*" = "allow";
            "*.env" = "deny";
            "*.env.*" = "deny";
            "*.env.example" = "allow";
          };
          read = "allow";
          write = "ask";
          edit = "ask";
          bash = {
            "*" = "ask";
            "git status" = "allow";
            "git diff" = "allow";
            "rm -rf *" = "deny";
            "sudo *" = "ask";
          };
          external_directory = "ask";
        };
        description = "Flat permission policy. Values are allow, ask, deny, deny-with-reason objects, or pattern maps.";
      };
      extraConfig = lib.mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Additional permission-system config fields.";
      };
    };

  config = lib.mkIf cfg.enable {
    pi.packageEntries = [ (packageLib.packageEntry cfg) ];
    pi.files."extensions/pi-permission-system/config.json" = permissionConfig;
  };
}
