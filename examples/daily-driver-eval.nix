let
  piNix = import ../default.nix { };
  configuration = piNix.piConfiguration {
    modules = [
      ./daily-driver.nix
    ];
  };
in
configuration.launcher // configuration
