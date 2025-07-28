{localFlake}: {
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with builtins;
with lib; let
  inherit
    (localFlake.lib)
    mkOverrideAtHmModuleLevel
    isModuleLoadedAndEnabled
    mkImpermanenceEnableOption
    ;

  cfg = config.tensorfiles.hm.programs.browsers.chromium;
  _ = mkOverrideAtHmModuleLevel;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.hm.system.impermanence
    else {};

  hyprlandCheck =
    isModuleLoadedAndEnabled config "tensorfiles.hm.desktop.window-managers.hyprland";

  braveCheck =
    cfg.pkg
    == pkgs.brave;
  isWayland = isModuleLoadedAndEnabled config "tensorfiles.hm.desktop.isWayland";
in {
  options.tensorfiles.hm.programs.browsers.chromium = with types; {
    enable = mkEnableOption ''
      TODO
    '';

    pkg = mkOption {
      type = package;
      default = pkgs.brave;
      description = ''
        Which package to use.
      '';
    };

    impermanence = {
      enable = mkImpermanenceEnableOption;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      programs.chromium = {
        enable = true;
        extensions = [
          {id = "mnjggcdmjocbbbhaepdhchncahnbgone";} # sponsor block
          {id = "cjpalhdlnbpafiamejdnhcphjbkeiagm";} # ublock
          {id = "nngceckbapebfimnlniiiahkandclblb";} # bitwarden
          {id = "iaiomicjabeggjcfkbimgmglanimpnae";} # tab manager
        ];

        package = cfg.pkg.override {
          nss = pkgs.nss_latest;
          commandLineArgs =
            [
              # Ungoogled features
              "--disable-search-engine-collection"
              "--extension-mime-request-handling=always-prompt-for-install"
              "--fingerprinting-canvas-image-data-noise"
              "--fingerprinting-canvas-measuretext-noise"
              "--fingerprinting-client-rects-noise"
              "--popups-to-tabs"
              "--show-avatar-button=incognito-and-guest"

              # Experimental features
              "--enable-features=${
                concatStringsSep "," [
                  "BackForwardCache:enable_same_site/true"
                  "CopyLinkToText"
                  "OverlayScrollbar"
                  "TabHoverCardImages"
                  "VaapiVideoDecoder"
                ]
              }"

              # Aesthetics
              "--force-dark-mode"

              # Performance
              "--enable-gpu-rasterization"
              "--enable-oop-rasterization"
              "--enable-zero-copy"
              "--ignore-gpu-blocklist"

              # Etc
              # "--gtk-version=4"
              "--disk-cache=$XDG_RUNTIME_DIR/chromium-cache"
              "--no-default-browser-check"
              "--no-service-autorun"
              "--disable-features=PreloadMediaEngagementData,MediaEngagementBypassAutoplayPolicies"
              "--disable-reading-from-canvas"
              "--no-pings"
              "--no-first-run"
              "--no-experiments"
              "--no-crash-upload"
              "--disable-wake-on-wifi"
              "--disable-breakpad"
              "--disable-sync"
              "--disable-speech-api"
              "--disable-speech-synthesis-api"
            ]
            # ++ optionals isWayland [
            #   # Wayland
            #   # Disabled because hardware acceleration doesn't work
            #   # when disabling --use-gl=egl, it's not gonna show any emoji
            #   # and it's gonna be slow as hell
            #   # "--use-gl=egl"
            #   "--ozone-platform=wayland"
            #   "--enable-features=UseOzonePlatform"
            # ]
            ;
        };
      };
    }
    # |----------------------------------------------------------------------| #
    (mkIf impermanenceCheck {
      home.persistence."${impermanence.persistentRoot}${config.home.homeDirectory}" = {
        directories = [
          ".config/BraveSoftware"
          ".cache/BraveSoftware"
        ];
      };
    })
    # |----------------------------------------------------------------------| #
    (mkIf hyprlandCheck
      # && cfg.pkg
      # == pkgs.brave
      (mkIf braveCheck {
        wayland.windowManager.hyprland.settings.windowrulev2 = [
          # do not idle while watching videos
          "idleinhibit fullscreen,class:^(brave)$"
          "idleinhibit focus,class:^(brave)$,title:(.*)(YouTube)(.*)"
          # float save dialogs
          # save as
          "float,initialClass:^(brave)$,initialTitle:^(Save File)$"
          "size <50% <50%,initialClass:^(brave)$,initialTitle:^(Save File)$"
          # save image
          "float,initialClass:^(brave)$,initialTitle:(.*)(wants to save)$"
          "size <50% <50%,initialClass:^(brave)$,initialTitle:(.*)(wants to save)$"
        ];
      }))
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
