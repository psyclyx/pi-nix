let
  piNix = import ../default.nix { };
  configuration = piNix.piConfiguration {
    modules = [
      ./basic.nix
    ];
  };
in
configuration.launcher // configuration
