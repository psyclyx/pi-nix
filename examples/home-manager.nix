{ piNix, ... }:

{
  imports = [
    piNix.homeManagerModules.default
  ];

  programs.pi-nix = {
    enable = true;

    profiles.pi.modules = [
      ./basic.nix
    ];
  };
}
