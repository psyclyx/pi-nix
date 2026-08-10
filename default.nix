{
  system ? builtins.currentSystem,
  sources ? import ./npins,
  nixpkgs ? sources.nixpkgs,
  pkgs ? import nixpkgs { inherit system; },
}:

let
  modules = import ./modules;
  registry = import ./registry;

  overlay = final: _prev: {
    pi = final.callPackage ./packages/pi {
      entry = (registry.packages or { }).pi or { };
    };
  };

  finalPkgs = pkgs.extend overlay;

  piPackages = {
    inherit (finalPkgs) pi;
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
    overlay
    ;

  lib = piLib;
  packages = piPackages;
  piConfiguration = piLib.piConfiguration;
  shell = import ./nix/shell.nix { pkgs = finalPkgs; };
  homeManagerModules = rec {
    default = import ./home-manager;
    pi-nix = default;
  };
}
