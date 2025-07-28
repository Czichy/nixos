{localFlake}: {
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtHmModuleLevel;

  cfg = config.tensorfiles.hm.services.x11.picom;
  _ = mkOverrideAtHmModuleLevel;
in {
  options.tensorfiles.hm.services.x11.picom = with types; {
    enable = mkEnableOption ''
      TODO
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      services.picom = {
        enable = _ true;
        # backend = _ "glx";
        activeOpacity = _ 1.0;
        fade = _ true;
        fadeDelta = _ 4;
        fadeSteps = _ [
          3.0e-2
          3.0e-2
        ];
        inactiveOpacity = _ 1.0;
        shadow = _ true;
        shadowOffsets = _ [
          (-5)
          (-5)
        ];
        shadowOpacity = _ 0.5;
        vSync = _ true;
        shadowExclude = _ [
          "! name~=''"
          "name = 'Notification'"
          "name = 'Plank'"
          "name = 'Docky'"
          "name = 'Kupfer'"
          "name = 'xfce4-notifyd'"
          "name = 'cpt_frame_window'"
          "name *= 'VLC'"
          "name *= 'compton'"
          "name *= 'picom'"
          "name *= 'Chromium'"
          "name *= 'Chrome'"
          "class_g = 'Firefox' && argb"
          "class_g = 'Conky'"
          "class_g = 'Kupfer'"
          "class_g = 'Synapse'"
          "class_g ?= 'Notify-osd'"
          "class_g ?= 'Cairo-dock'"
          "class_g ?= 'Xfce4-notifyd'"
          "class_g ?= 'Xfce4-power-manager'"
          "_GTK_FRAME_EXTENTS@:c"
          "_NET_WM_STATE@:32a *= '_NET_WM_STATE_HIDDEN'"
        ];
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
