{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.pi.profiles.coding;
in
{
  options.pi.profiles.coding.enable = lib.mkEnableOption "a baseline coding-agent profile";

  config = lib.mkIf cfg.enable {
    pi = {
      enable = true;

      extraPackages = with pkgs; [
        git
        jq
        ripgrep
      ];

      settings = {
        tools = {
          git = true;
          shell = true;
        };

        workspace = {
          search = "ripgrep";
        };
      };
    };
  };
}
