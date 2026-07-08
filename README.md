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
nix build --no-link -f default.nix packages.pi
```

Build a launcher:

```sh
nix build --impure --expr 'let piNix = import ./. {}; in (piNix.piConfiguration { modules = [ ./examples/basic.nix ]; }).launcher'
```

## Home Manager

The Home Manager module supports multiple named profiles. Each profile gets its
own generated command; the command defaults to the profile name and can be
overridden with `binaryName`.

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

The launcher writes generated `settings.json` and package sidecar JSON under a
managed `PI_CODING_AGENT_DIR`. By default it links only `auth.json` from
`~/.pi/agent` when present, so generated configurations do not read the normal
non-auth global Pi config. CLI trust/context behavior is left to Pi unless you
set `pi.runtime.projectTrust`, `pi.runtime.contextFiles`, or `pi.runtime.extraArgs`.

## Packages

Curated packages are exposed as typed module options under `pi.packages.*`.
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
environment. Pi itself is packaged here, not taken from nixpkgs. Npm artifact
identity lives in `registry/packages.json`: package name, version, tarball,
flat hash, unpacked source hash, and any lockfile integrity repairs required by
the published npm tarball.

Refresh or add an npm package with:

```sh
scripts/import-npm-pi-package pi @earendil-works/pi-coding-agent --agent
scripts/import-npm-pi-package web-access pi-web-access --module webAccess --category web
```

The importer is a shell script. It uses `npm view` for metadata and
`nix store prefetch-file --unpack --json` for recursive source hashes. Pi's npm
dependencies are built with `pkgs.importNpmLock`, so dependency tarballs are
fetched directly from lockfile integrity data.

For auto-updates, keep npins for repository pins and the registry for npm
artifacts. `scripts/update` updates npm/Pi registry artifacts, verifies hashes,
and checks that the module scaffold still evaluates. Pass registry aliases to
update only those entries.

```sh
scripts/update
scripts/update pi rpiv rpiv-workflow
direnv allow
```

Update npins only when you explicitly want to move repository pins:

```sh
scripts/update-npins
scripts/update --npins
```
