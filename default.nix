{
  system ? builtins.currentSystem,
  sources ? import ./npins,
  pkgs ? import sources.nixpkgs { inherit system; },
}:

let
  modules = import ./modules;
  registry = import ./registry;
  piPackages = import ./packages {
    inherit pkgs sources registry;
  };
  piLib = import ./lib {
    inherit
      pkgs
      modules
      piPackages
      registry
      ;
  };
in
{
  inherit
    pkgs
    sources
    registry
    modules
    piPackages
    ;

  lib = piLib;
  packages = piPackages;
  piConfiguration = piLib.piConfiguration;
}
