pkgs:

with pkgs;

let
  exe =
    if pkgs.stdenv.targetPlatform.isx86_64 then haskell.lib.justStaticExecutables else pkgs.lib.id;
in
[
  #(pkgs.lowPrio gdtoolkit_4)
]
