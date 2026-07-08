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
  cfg = config.pi.packages.context7;
  entry = packageLib.registryEntry registry "context7";
  piPackage = piPackages.pi or config.pi.package;
  piPeer = packageLib.piPackageNodeModule piPackage;
  source = packageLib.npmPackageSource {
    inherit pkgs entry;
    nodeModules = {
      typebox = piPeer "typebox";
      "@earendil-works/pi-coding-agent" = "${piPackage}/lib/node_modules/@earendil-works/pi-coding-agent";
    };
  };
in
{
  options.pi.packages.context7 =
    packageLib.packageResourceOptions {
      defaultSource = source;
      description = "Context7 documentation tools for Pi";
    }
    // {
      unsafeApiKey = packageLib.nullable lib.types.str // {
        description = "Context7 API key. Prefer CONTEXT7_API_KEY in the runtime environment; this value is written into the wrapper environment.";
      };
    };

  config = lib.mkIf cfg.enable {
    pi.packageEntries = [ (packageLib.packageEntry cfg) ];
    pi.environment = lib.optionalAttrs (cfg.unsafeApiKey != null) {
      CONTEXT7_API_KEY = cfg.unsafeApiKey;
    };
  };
}
