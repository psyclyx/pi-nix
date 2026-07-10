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
    telemetry = false;
    installTelemetry = false;
  };

  pi.core = {
    quietStartup = true;
    enableAnalytics = false;
    resources.enableSkillCommands = true;
    compaction.enabled = true;
  };

  pi.settings = {
    model = "pi";
    instructions = [
      "Read the repository before editing."
      "Keep changes scoped to the requested task."
      "Prefer package-managed tools and configuration over ad hoc global state."
    ];
    tools = {
      git = true;
      shell = true;
    };
    workspace.search = "ripgrep";
  };

  pi.packages = {
    superpowers.enable = true;
    askUser.enable = true;
    plan.enable = true;
    addDir.enable = true;
    claudeCli.enable = true;
    rawPaste.enable = true;
    usage.enable = true;
  };
}
