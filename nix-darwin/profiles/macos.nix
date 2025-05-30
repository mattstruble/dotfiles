{ config
, lib
, pkgs
, ...
}:
{

  # Replace default symlinking functionality with copying
  # https://github.com/YorikSar/dotfiles/blob/f83b0b5f32d9f6f410eafe42be44d2a14b7effb8/nix/profiles/macos.nix
  # FIXME: Get xattr working in nix rebuild so that unchanged apps aren't copied every time
  home.file."Applications/Home Manager Apps".enable = false;
  home.activation.copyApps =
    let
      apps = pkgs.buildEnv {
        name = "home-manager-applications";
        paths = config.home.packages;
        pathsToLink = "/Applications";
      };
      v = "\${VERBOSE_ARG:+-v}";
    in
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      baseDir="$HOME/Applications/Home Manager Apps"
      $DRY_RUN_CMD mkdir -p "$baseDir"
      shopt -s nullglob
      for app in "$baseDir"/*; do
        if [ ! -e "${apps}/Applications/$(basename "$app")" ]; then
          $DRY_RUN_CMD rm -r ${v} "$app"
        fi
      done
      for app in ${apps}/Applications/*; do
        source="$(readlink "$app")"
        target="$baseDir/$(basename "$app")"
        # if [ -e "$target" ]; then
          # oldsource="$(xattr -p home-manager-source "$target" || true)"
          # if [ "$source" = "$oldsource" ]; then
          #   continue
          # fi
        # fi
        temp="$(mktemp -u "$target.XXXXXX")"
        $DRY_RUN_CMD cp ${v} -HLR "$source" "$temp"
        $DRY_RUN_CMD chmod ${v} -R +w "$temp"
        # $DRY_RUN_CMD xattr -w home-manager-source "$source" "$temp"
        if [ -e "$target" ]; then
          $DRY_RUN_CMD rm -r ${v} "$target"
        fi
        $DRY_RUN_CMD mv ${v} "$temp" "$target"
      done
    '';
}
