let
  npins = import ./npins;
in
{
  system ? builtins.currentSystem,
  sources ? npins,
  nixpkgs ? sources.nixpkgs,
  # External dep — the pi tarball pin (the package itself is built from the
  # registry entry; the pin stays as a seam).
  pi ? sources.pi,
  pkgs ? import nixpkgs { inherit system; },
  ...
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
    # own pins as the base, then the batch seam, then the named dep args.
    sources = npins // sources // { inherit pi; };
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
