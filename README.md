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

Curated packages are exposed as typed module options under `pi.packages.*`.
Most mirror the LazyPi package catalog; Superpowers is added separately from the
official `obra/superpowers` Pi package. `examples/daily-driver.nix` enables a
small default set without embedding secrets or enabling browser-cookie access.

The current catalog is:

```text
subagents, askUser, mcp, webAccess, memory, plan, simplify, addDir,
promptTemplates, claudeCli, plannotator, slopchop, extensionSettings, powerbar,
usage, rawPaste, todos, btw, interactiveShell, autoresearch, ralphWiggum,
compound, hackerman, curatedThemes, terminalTheme
```

The additional curated package is `superpowers`.

Compound is modeled as a generated local Pi package in the Nix store. Enabling
`pi.packages.compound` also enables `subagents` and `askUser` by default because
the generated skills rely on those tools.

For personal config, local iteration, or a package from git/npm that does not
yet have a typed module, use `pi.packages.custom`:

```nix
{
  pi.packages.webAccess = {
    enable = true;
    workflow = "none";
  };

  pi.packages.custom.myPackage = {
    source = "git:github.com/me/my-pi-package@v1";
    developmentPath = "/home/me/src/my-pi-package";
    extensions = [ "extensions/*.ts" ];
  };
}
```

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
