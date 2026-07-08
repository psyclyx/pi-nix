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
  cfg = config.pi.packages.todo;
  entry = packageLib.registryEntry registry "todo";
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
      "@juicesharp/rpiv-i18n" = config.pi.packages.rpivI18n.source;
    };
    patches = ''
      substituteInPlace "$out/config.ts" \
        --replace-fail 'const CONFIG_PATH = configPath("rpiv-todo");' \
        'const CONFIG_PATH = process.env.RPIV_TODO_CONFIG_PATH?.trim() || configPath("rpiv-todo");'
    '';
  };
  todoConfig = packageLib.clean {
    guidance = packageLib.clean cfg.guidance;
  };
in
{
  options.pi.packages.todo =
    packageLib.packageResourceOptions {
      defaultSource = source;
      description = "RPiV todo overlay for Pi";
    }
    // {
      guidance = {
        promptSnippet = packageLib.nullable types.str // {
          description = "guidance.promptSnippet.";
        };
        promptGuidelines = packageLib.nullable (types.listOf types.str) // {
          description = "guidance.promptGuidelines.";
        };
      };
    };

  config = lib.mkIf cfg.enable {
    pi.packageEntries = [ (packageLib.packageEntry cfg) ];
    pi.files."config/rpiv-todo/config.json" = todoConfig;
    pi.agentDirEnvironment.RPIV_TODO_CONFIG_PATH = "config/rpiv-todo/config.json";
  };
}
