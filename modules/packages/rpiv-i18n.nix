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
  cfg = config.pi.packages.rpivI18n;
  entry = packageLib.registryEntry registry "rpiv-i18n";
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
    nodeModules."@juicesharp/rpiv-config" = rpivConfig;
    patches = ''
      substituteInPlace "$out/i18n.ts" \
        --replace-fail 'const LOCALE_CONFIG_PATH = configPath("rpiv-i18n", "locale.json");' \
        'const LOCALE_CONFIG_PATH = process.env.RPIV_I18N_CONFIG_PATH?.trim() || configPath("rpiv-i18n", "locale.json");'
    '';
  };
  localeConfig = packageLib.clean {
    inherit (cfg) locale;
  };
in
{
  options.pi.packages.rpivI18n =
    packageLib.packageResourceOptions {
      defaultSource = source;
      description = "RPiV localization support";
    }
    // {
      locale =
        packageLib.nullable (
          types.enum [
            "de"
            "en"
            "es"
            "fr"
            "pt"
            "pt-BR"
            "ru"
            "uk"
            "zh"
          ]
        )
        // {
          description = "Persisted rpiv-i18n locale.";
        };
      environment = lib.mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Raw rpiv-i18n environment overrides.";
      };
    };

  config = lib.mkIf cfg.enable {
    pi.packageEntries = [ (packageLib.packageEntry cfg) ];
    pi.files."config/rpiv-i18n/locale.json" = localeConfig;
    pi.agentDirEnvironment.RPIV_I18N_CONFIG_PATH = "config/rpiv-i18n/locale.json";
    pi.environment = cfg.environment;
  };
}
