{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (config.home.sessionVariables) BROWSER;

  hasAnthropicSecret = config.age.secrets ? anthropic_api_key;

  load-secrets-env = pkgs.writeShellScript "load-secrets-env" ''
    ANTHROPIC_API_KEY="$(cat ${config.age.secrets.anthropic_api_key.path} 2>/dev/null)"
    if [ -n "$ANTHROPIC_API_KEY" ]; then
      export ANTHROPIC_API_KEY
      # Propagate to both D-Bus activation environment AND systemd user manager
      ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd ANTHROPIC_API_KEY
    fi
  '';
in {
  programs.niri.settings.spawn-at-startup =
    (lib.optional hasAnthropicSecret {command = ["sh" "-c" "${load-secrets-env}"];})
    ++ [
      {command = ["systemctl" "--user" "start" "hyprpolkitagent"];}
      {command = ["arrpc"];}
      {command = ["xwayland-satellite"];}
      {command = ["hyprlock"];}
      {command = ["swww-daemon"];}
      {command = ["wl-paste" "--watch" "cliphist" "store"];}
      {command = ["wl-paste" "--type text" "--watch" "cliphist" "store"];}
      {command = ["${pkgs.swaynotificationcenter}/bin/swaync"];}
      {command = ["swayosd-server"];}
      {command = ["xprop -root -f _XWAYLAND_GLOBAL_OUTPUT_SCALE 32c -set _XWAYLAND_GLOBAL_OUTPUT_SCALE 1"];}
      {command = ["ib-start" "--app" "tws" "--mode" "paper" "--channel" "latest"];}
      {command = ["${BROWSER}"];}
    ];
}
