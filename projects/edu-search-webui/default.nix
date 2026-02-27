# Edu-Search Web-UI – Nix-Derivation
#
# Baut die statische SPA (Single-Page-Application) für die
# Unterrichtsmaterial-Suche als Nix-Store-Pfad.
#
# Verwendung in webui.nix:
#   eduWebUI = import ../../../../projects/edu-search-webui { inherit pkgs; };
#   root = "${eduWebUI}";
#
# Lokale Entwicklung:
#   python3 -m http.server 8080 -d src/
{pkgs ? import <nixpkgs> {}}: let
  src = ./src;
in
  pkgs.runCommand "edu-search-webui" {
    inherit src;
  } ''
    mkdir -p $out
    cp -r $src/* $out/
  ''
