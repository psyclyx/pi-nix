{ pkgs }:

let
  lib = pkgs.lib;
in
pkgs.mkShellNoCC {
  packages =
    with pkgs;
    [
      git
      jq
      nodejs
      npins
      ripgrep
    ]
    ++ lib.optionals (pkgs ? deadnix) [ pkgs.deadnix ]
    ++ lib.optionals (pkgs ? nil) [ pkgs.nil ]
    ++ lib.optionals (pkgs ? nixd) [ pkgs.nixd ]
    ++ lib.optionals (pkgs ? nixfmt) [ pkgs.nixfmt ]
    ++ lib.optionals (pkgs ? statix) [ pkgs.statix ];

  shellHook = ''
    export PI_NIX_ROOT="$PWD"
  '';
}
