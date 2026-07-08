let
  piNix = import ../default.nix { };
in
piNix.piConfiguration {
  modules = [
    ./basic.nix
  ];
}
