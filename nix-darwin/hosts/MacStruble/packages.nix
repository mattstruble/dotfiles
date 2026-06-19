pkgs:

with pkgs;

[
  (pkgs.lib.lowPrio gdtoolkit_4)
  gdscript-formatter
  opentofu
]
