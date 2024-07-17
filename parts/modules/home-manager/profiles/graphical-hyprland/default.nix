# --- parts/modules/home-manager/profiles/graphical-plasma/default.nix
#
# Author:  czichy <christian@czichy.com>
# URL:     https://github.com/czichy/tensorfiles
# License: MIT
#
# 888                                                .d888 d8b 888
# 888                                               d88P"  Y8P 888
# 888                                               888        888
# 888888 .d88b.  88888b.  .d8888b   .d88b.  888d888 888888 888 888  .d88b.  .d8888b
# 888   d8P  Y8b 888 "88b 88K      d88""88b 888P"   888    888 888 d8P  Y8b 88K
# 888   88888888 888  888 "Y8888b. 888  888 888     888    888 888 88888888 "Y8888b.
# Y88b. Y8b.     888  888      X88 Y88..88P 888     888    888 888 Y8b.          X88
#  "Y888 "Y8888  888  888  88888P'  "Y88P"  888     888    888 888  "Y8888   88888P'
{ localFlake }:
{
  pkgs,
  config,
  lib,
  ...
}:
with builtins;
with lib;
let
  inherit (localFlake.lib.tensorfiles) mkOverrideAtHmProfileLevel;

  cfg = config.tensorfiles.hm.profiles.graphical-hyprland;
  _ = mkOverrideAtHmProfileLevel;
in
{
  options.tensorfiles.hm.profiles.graphical-hyprland = with types; {
    enable = mkEnableOption ''
      TODO
    '';
  };

  #imports = with inputs; [stylix.nixosModules.stylix];

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    #(import ./rc2nix.nix)
    # |----------------------------------------------------------------------| #
    {
      tensorfiles.hm = {
        profiles.headless.enable = _ true;
        # hardware.nixGL.enable = _ true;
        services.wayland.window-managers.hyprland.enable = _ true;
        services.swaync.enable = _ true;
        programs = {
          terminals.foot.enable = _ true;
          browsers.firefox.enable = _ true;
          editors.helix.enable = _ true;
          wlogout.enable = _ true;
          wofi.enable = _ true;
        };

        #services = {
        #  pywalfox-native.enable = _ true;
        #};
      };

      # services.flameshot = {
      #   enable = _ true;
      #   settings = {
      #     General.showStartupLaunchMessage = _ false;
      #   };
      # };

      services.rsibreak.enable = _ false;

      home.sessionVariables = {
        # Default programs
        BROWSER = _ "firefox";
        EXPLORER = _ "yazi";
        TERMINAL = _ "foot";
        EDITOR = _ "hx";

        # Wayland
        MOZ_ENABLE_WAYLAND = 1;
        QT_QPA_PLATFORM = "wayland";
        LIBSEAT_BACKEND = "logind";
      };
      home.packages = with pkgs; [
        grim
        imv
        pulseaudio
        slurp
        waypipe
        wf-recorder
        wl-clipboard
        cliphist
        ydotool
        (pkgs.rustPlatform.buildRustPackage rec {
          pname = "swayosd";
          version = "5c2176ae6a01a18fdc2b0f5d5f593737b5765914";

          src = pkgs.fetchFromGitHub {
            owner = "ErikReider";
            repo = pname;
            rev = version;
            hash = "sha256-rh42J6LWgNPOWYLaIwocU1JtQnA5P1jocN3ywVOfYoc=";
          };

          cargoSha256 = "f/MaNADm/jkEqofd5ixQBcsPr3mjt4qTMRrr0A0J5sI=";

          nativeBuildInputs = with pkgs; [ pkg-config ];
          buildInputs = with pkgs; [
            glib
            atk
            gtk3
            gtk-layer-shell
            pulseaudio
          ];

          meta = with lib; {
            description = "A GTK based on screen display for keyboard shortcuts like caps-lock and volume";
            homepage = "https://github.com/ErikReider/SwayOSD";
            license = licenses.gpl3;
          };
        })
      ];

      fonts.fontconfig.enable = _ true;

      services.network-manager-applet.enable = _ true;

      #    programs = {
      #  fish.loginShellInit = ''
      #    if test (tty) = "/dev/tty1"
      #      set _JAVA_AWT_WM_NONEREPARENTING 1
      #      exec Hyprland &> /dev/null
      #    end
      #  '';
      #  zsh.loginExtra = ''
      #    if [ "$(tty)" = "/dev/tty1" ]; then
      #      exec Hyprland &> /dev/null
      #    fi
      #  '';
      #  zsh.profileExtra = ''
      #    if [ "$(tty)" = "/dev/tty1" ]; then
      #      exec Hyprland &> /dev/null
      #    fi
      #  '';
      #};
      ## WARN: Check if this breaks when the hyprland module is not in imports.
      ## Enter Hyprland when logging into tty1 if Hyprland is enabled.
      xdg.configFile."nushell/login.nu".text = ''
        if (tty) == "/dev/tty1" {
          exec Hyprland | ignore
        }
      '';
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.tensorfiles.maintainers; [ czichy ];
}
