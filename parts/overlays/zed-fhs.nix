# Overlay that adds FHS wrapper to zed-editor from the Zed flake.
# The Zed flake's overlay provides `zed-editor` but without the `.fhs`
# attribute that nixpkgs' version has. This overlay adds it back so that
# `pkgs.zed-editor-fhs` (which is `pkgs.zed-editor.fhs`) keeps working.
final: prev: {
  zed-editor = prev.zed-editor.overrideAttrs (old: {
    passthru = (old.passthru or {}) // {
      fhs = final.buildFHSEnv {
        name = "zeditor";
        targetPkgs = pkgs:
          with pkgs; [
            glibc
            openssl
            libcap
            zlib
          ];
        extraBwrapArgs = [
          "--bind-try /etc/nixos/ /etc/nixos/"
          "--ro-bind-try /etc/xdg/ /etc/xdg/"
        ];
        extraInstallCommands = ''
          ln -s "${prev.zed-editor}/share" "$out/"
        '';
        runScript = "${prev.zed-editor}/bin/zeditor";
        passthru = {
          executableName = "zeditor";
          inherit (prev.zed-editor) pname version;
        };
        meta = prev.zed-editor.meta or {};
      };
    };
  });
}
