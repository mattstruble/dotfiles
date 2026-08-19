{ config, lib, pkgs, ... }:

let
  sbarLua = pkgs.stdenv.mkDerivation {
    pname = "sbar-lua";
    version = "unstable-2025-01-01";

    src = pkgs.fetchFromGitHub {
      owner = "FelixKratz";
      repo = "SbarLua";
      rev = "dba9cc421b868c918d5c23c408544a28aadf2f2f";
      sha256 = "sha256:1wkfygk3qk8navj42n48wnqzksilc2virfb44w5p00wzvfnx64ln";
    };

    nativeBuildInputs = [ pkgs.clang ];
    buildInputs = [ pkgs.lua5_4 ];

    buildPhase = ''
      clang \
        -std=c99 -O3 -shared -fPIC \
        -arch arm64 \
        -I${pkgs.lua5_4}/include \
        src/sketchybar.c src/cJSON.c src/parsing.c \
        -L${pkgs.lua5_4}/lib -llua \
        -framework CoreFoundation \
        -o sketchybar.so
    '';

    installPhase = ''
      mkdir -p $out/lib
      cp sketchybar.so $out/lib/sketchybar.so
    '';

    meta = {
      description = "Lua bindings for SketchyBar";
      homepage = "https://github.com/FelixKratz/SbarLua";
      platforms = [ "aarch64-darwin" ];
    };
  };
in
{
  home.file.".local/share/sketchybar_lua/sketchybar.so".source =
    "${sbarLua}/lib/sketchybar.so";
}
