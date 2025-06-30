{
  pkgs,
  config,
}: let
  inherit (config.home.sessionVariables) TERMINAL BROWSER EXPLORER; # EDITOR
in {
  browser = BROWSER;
  # browser = "${pkgs.vivaldi}/bin/vivaldi";
  terminal = TERMINAL;
  # terminal = "${pkgs.foot}/bin/foot";
  fileManager = EXPLORER;
  editor = "zeditor";
  launcher = "walker";

  screenshotArea = "${pkgs.bash}/bin/bash -c '${pkgs.grim}/bin/grim -g \"\\\$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.wl-clipboard}/bin/wl-copy'";
  screenshotWindow = "${pkgs.bash}/bin/bash -c '${pkgs.grim}/bin/grim -g \"\\\$(${pkgs.slurp}/bin/slurp -w)\" - | ${pkgs.wl-clipboard}/bin/wl-copy'";
  screenshotOutput = "${pkgs.bash}/bin/bash -c '${pkgs.grim}/bin/grim - | ${pkgs.wl-clipboard}/bin/wl-copy'";
}
