{
  pkgs,
  sources,
  registry ? import ../registry,
}:

let
  packageRegistry = registry.packages or { };

  piEntry = packageRegistry.pi or { };

  self = {
    pi = pkgs.callPackage ./pi {
      entry = piEntry;
    };
  };
in
self
