let
  piNix = import ../default.nix { };
in
piNix.piConfiguration {
  modules = [
    ./daily-driver.nix
  ];
}
