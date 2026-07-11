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

  pi.runtime = {
    launcherName = "pi";
    auth.mode = "existing";
    projectConfig = "ask";
  };

  # Telemetry/analytics are off by default via pi.telemetry.enable.

  pi.settings = {
    quietStartup = true;
    enableSkillCommands = true;
    compaction.enabled = true;
  };

  pi.packages.registry = {
    superpowers.enable = true;
    pi-ask-user.enable = true;
    plan.enable = true;
    add-dir.enable = true;
    claude-cli.enable = true;
    raw-paste.enable = true;
    usage.enable = true;
  };
}
