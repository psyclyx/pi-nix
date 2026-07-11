{ pkgs, ... }:

{
  pi = {
    enable = true;

    extraPackages = with pkgs; [
      git
      jq
      ripgrep
    ];
  };

  pi.settings.quietStartup = true;
}
