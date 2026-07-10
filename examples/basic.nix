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

  pi.settings = {
    model = "pi";
    instructions = [
      "Read the repository before editing."
      "Keep changes scoped to the requested task."
    ];
    tools = {
      git = true;
      shell = true;
    };
    workspace.search = "ripgrep";
  };
}
