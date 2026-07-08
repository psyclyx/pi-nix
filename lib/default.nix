{
  pkgs,
  modules ? import ../modules,
  piPackages ? import ../packages {
    inherit pkgs;
    sources = import ../npins;
  },
  registry ? import ../registry,
}:

let
  inherit (pkgs) lib;
  defaultModules = modules;

  writeJsonFile =
    name: value:
    pkgs.writeText (builtins.replaceStrings [ "/" ] [ "-" ] name) (builtins.toJSON value + "\n");

  installJsonCommands =
    files:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        relativePath: file:
        let
          directory = builtins.dirOf relativePath;
        in
        ''
          mkdir -p "$agent_dir"/${lib.escapeShellArg directory}
          install -m 0600 ${file} "$agent_dir"/${lib.escapeShellArg relativePath}
        ''
      ) files
    );

  exportCommands =
    environment:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}") environment
    );

  exportAgentDirCommands =
    environment:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: relativePath: ''export ${name}="$agent_dir"/${lib.escapeShellArg relativePath}''
      ) environment
    );
in
rec {
  inherit defaultModules;

  evalPiModules =
    {
      modules ? [ ],
      specialArgs ? { },
      extraSpecialArgs ? { },
      ...
    }:
    lib.evalModules {
      specialArgs = {
        inherit pkgs piPackages registry;
        piNix = self;
      }
      // specialArgs
      // extraSpecialArgs;

      modules = defaultModules ++ modules;
    };

  piConfiguration =
    {
      modules ? [ ],
      specialArgs ? { },
      extraSpecialArgs ? { },
      ...
    }:
    let
      evaluated = evalPiModules {
        inherit modules specialArgs extraSpecialArgs;
      };
      cfg = evaluated.config.pi;
      generatedFiles = cfg.files // {
        "settings.json" = cfg.settings;
      };
      fileDrvs = lib.mapAttrs writeJsonFile generatedFiles;
      wrapperArgs =
        lib.optional (cfg.runtime.projectTrust == "approve") "--approve"
        ++ lib.optional (cfg.runtime.projectTrust == "no-approve") "--no-approve"
        ++ lib.optional (cfg.runtime.contextFiles == false) "--no-context-files"
        ++ cfg.runtime.extraArgs;
      wrapperArgsString = lib.concatMapStringsSep " " lib.escapeShellArg wrapperArgs;
      authSource =
        if cfg.runtime.auth.mode == "existing" then
          ''"''${PI_NIX_AUTH_DIR:-$HOME/.pi/agent}"''
        else if cfg.runtime.auth.mode == "directory" then
          ''"${cfg.runtime.auth.directory}"''
        else
          ''""'';
      launcher =
        if cfg.package == null then
          null
        else
          pkgs.writeShellApplication {
            name = cfg.runtime.launcherName;
            runtimeInputs = [
              cfg.package
              pkgs.coreutils
            ];
            text = ''
              agent_dir="''${PI_NIX_AGENT_DIR:-${cfg.runtime.stateDir}}"
              package_dir="''${PI_NIX_PACKAGE_DIR:-${cfg.runtime.packageDir}}"
              auth_source=${authSource}

              mkdir -p "$agent_dir" "$package_dir"

              if [ -n "$auth_source" ] && [ -e "$auth_source/auth.json" ] && [ ! -e "$agent_dir/auth.json" ]; then
                ln -s "$auth_source/auth.json" "$agent_dir/auth.json"
              fi

              ${installJsonCommands fileDrvs}

              export PI_CODING_AGENT_DIR="$agent_dir"
              export PI_PACKAGE_DIR="$package_dir"
              ${exportAgentDirCommands cfg.agentDirEnvironment}
              ${exportCommands cfg.environment}

              exec ${lib.getExe cfg.package} ${wrapperArgsString} "$@"
            '';
          };
    in
    {
      inherit pkgs;
      inherit (evaluated) config options;

      settingsFile = fileDrvs."settings.json";
      configFile = fileDrvs."settings.json";
      files = fileDrvs;
      environment = cfg.environment;
      extraPackages = cfg.extraPackages;
      inherit launcher;
      package = cfg.package;
      packages =
        cfg.extraPackages
        ++ lib.optional (cfg.package != null) cfg.package
        ++ lib.optional (launcher != null) launcher;
    };

  self = {
    inherit
      defaultModules
      evalPiModules
      piPackages
      piConfiguration
      pkgs
      registry
      ;
    packages = piPackages;
  };
}
