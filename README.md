# pi-nix

Nix module scaffolding for composing Pi coding agent configurations.

The shape is intentionally close to projects like nvf: import the library, pass
Nix modules to `piConfiguration`, and let the module system merge profiles,
settings, packages, and launch environment data.

## Usage

```nix
let
  piNix = import ./. { };
in
piNix.piConfiguration {
  modules = [
    ./examples/basic.nix
  ];
}
```

Evaluate the example:

```sh
nix eval -f examples/eval.nix config.pi.settings --json
nix eval -f examples/daily-driver-eval.nix config.pi.settings --json
nix build --no-link -f default.nix packages.pi
```

Build a launcher:

```sh
nix-build examples/daily-driver-eval.nix
```

## Home Manager

The Home Manager module supports multiple named profiles. Each profile gets its
own generated command; the command defaults to the profile name and can be
overridden with `binaryName`. Profile entries have an `enable` option that
defaults to true. When `programs.pi-nix.enable` is set, `profiles.pi` defaults
to the daily-driver module as one top-level `mkDefault` profile; assign any
`profiles.pi.*` option normally to replace that default profile.

```nix
{
  imports = [
    piNix.homeManagerModules.default
  ];

  programs.pi-nix = {
    enable = true;

    profiles.pi.modules = [
      ./pi.nix
    ];

    profiles.review = {
      binaryName = "pi-review";
      modules = [ ./review.nix ];
    };
  };
}
```

The launcher writes generated `settings.json` and package config files under
`PI_CODING_AGENT_DIR`, and points `PI_PACKAGE_DIR` at the packaged Pi node module
in the Nix store. By default it links only `auth.json` from `~/.pi/agent` when
present, so generated configurations do not read the normal non-auth global Pi
config. CLI trust/context behavior is left to Pi unless you set
`pi.runtime.projectTrust`, `pi.runtime.contextFiles`, or `pi.runtime.extraArgs`.

## Packages

Packages get into a Pi profile two ways. There is no per-package typed module —
package-specific settings are set through freeform `pi.settings` / `pi.files` /
`pi.environment`.

`pi.packages.registry.<name>` resolves a curated package by name from the pinned
registry and builds it as a Nix-managed, offline source. The attribute name is
the registry entry name. Each entry exposes the generic resource knobs from
`packageResourceOptions` (`source`, `developmentPath`, `autoload`,
`extensions`/`skills`/`prompts`/`themes` filters) plus an `order` for its
position in the settings.json `packages` array.

```nix
{
  pi.packages.registry = {
    superpowers.enable = true;
    pi-ask-user.enable = true;
    plan.enable = true;
    usage.enable = true;
  };
}
```

Registry entry names live in `registry/packages.json` under `piPackages`:

```text
add-dir, autoresearch, btw, claude-cli, curated-themes,
extension-settings, hackerman, interactive-shell, mcp, memory,
pi-ask-user, plan, plannotator, powerbar, prompt-templates, ralph-wiggum,
raw-paste, simplify, slopchop, subagents, superpowers, terminal-theme, todos,
usage, web-access
```

`pi.packages.custom.<name>` takes an arbitrary `source` string (`npm:`, `git:`,
a protocol URL, or a path) that Pi fetches at runtime, and carries its own
freeform `settings`/`files`/`environment` for anything a package needs:

```nix
{
  pi.packages.custom.myPackage = {
    source = "git:github.com/me/my-pi-package@v1";
    developmentPath = "/home/me/src/my-pi-package";
    extensions = [ "extensions/*.ts" ];
  };
}
```

## Web Search Secrets

`pi-web-access` reads provider keys from environment variables, so pi-nix exposes
`pi.webSearch.keyFiles` for secrets instead of putting API keys in
`web-search.json` or the Nix store. Each value is a runtime path read by the
generated launcher before Pi starts.

```nix
{
  pi.webSearch = {
    settings = {
      provider = "exa";
      workflow = "none";
      allowBrowserCookies = false;
    };

    keyFiles = {
      openai = "/run/secrets/openai-api-key";
      brave = "/run/secrets/brave-api-key";
      exa = "/run/secrets/exa-api-key";
    };
  };
}
```

Setting `pi.webSearch.settings` or `pi.webSearch.keyFiles` enables the
`web-access` registry package by default. Known API-key fields such as
`openaiApiKey` and `geminiApiKey` trigger an evaluation warning under
`pi.webSearch.settings`; prefer `keyFiles` or the generic
`pi.environmentFiles` option so secrets stay out of the Nix store.

## Registry

`nixpkgs` is pinned with npins only to provide a reproducible build
environment. Pi itself is packaged here, not taken from nixpkgs. Package
identity lives in `registry/packages.json`: package name, version, tarball,
flat hash, unpacked source hash, and any lockfile integrity repairs required by
published npm tarballs.

Refresh or add package sources with:

```sh
scripts/import-npm-pi-package pi @earendil-works/pi-coding-agent --agent
scripts/import-npm-pi-package web-access pi-web-access --module webAccess --category web
scripts/import-github-pi-package superpowers obra/superpowers --module superpowers --category workflow
scripts/import-github-pi-package todos tintinweb/pi-manage-todo-list --module todos --category ui
```

The importers are shell scripts. They use `npm view` or GitHub tags for
metadata and `nix store prefetch-file --unpack --json` for recursive source
hashes. Pi package dependencies are imported transitively into
`npmPackages`; dependency aliases include the requested range, such as
`entities@^6.0.0`, so two packages can depend on different versions of the same
npm package without colliding. Pi's own npm dependencies are built with
`pkgs.importNpmLock`, so dependency tarballs are fetched directly from lockfile
integrity data.

For auto-updates, keep npins for repository pins and the registry for Pi/npm
artifacts. `scripts/update` updates npm and GitHub-backed Pi registry artifacts,
verifies hashes, and checks that the module scaffold still evaluates. Pass
registry aliases to update only those entries.

```sh
scripts/update
scripts/update pi subagents web-access
direnv allow
```

Update npins only when you explicitly want to move repository pins:

```sh
scripts/update-npins
scripts/update --npins
```
