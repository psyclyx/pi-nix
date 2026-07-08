{ ... }:

{
  pi.profiles.coding.enable = true;

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
  };

  pi.packages = {
    superpowers = {
      enable = true;
      disableTelemetry = true;
    };

    context7.enable = true;

    lens = {
      enable = true;
      projectConfig = false;
      contextInjection.enabled = false;
    };

    statusline = {
      enable = true;
      palette = "mono";
      density = "compact";
      segments = [
        "model"
        "cwd"
        "branch"
        "tools"
        "context"
      ];
    };
  };
}
