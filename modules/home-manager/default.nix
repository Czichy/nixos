{
  config,
  lib,
  inputs,
  self,
  ...
}: let
  inherit (inputs.flake-parts.lib) importApply;
  inherit (self) secretsPath pubkeys;
  localFlake = self;
in {
  options.flake.homeModules = lib.mkOption {
    type = with lib.types; lazyAttrsOf unspecified;
    default = {};
  };

  config.flake.homeModules = {
    # -- hardware --
    hardware_nixGL = importApply ./hardware/nixGL.nix {inherit localFlake inputs;};
    hardware_monitors = importApply ./hardware/monitors.nix {inherit localFlake;};

    # -- misc --
    misc_gtk = importApply ./misc/gtk.nix {inherit localFlake;};
    misc_xdg = importApply ./misc/xdg.nix {inherit localFlake;};

    # -- profiles --
    profiles_base = importApply ./profiles/base.nix {inherit localFlake;};
    profiles_graphical = importApply ./profiles/graphical.nix {inherit localFlake;};
    # profiles_graphical-plasma = importApply ./profiles/graphical-plasma {inherit localFlake inputs;};
    profiles_graphical-hyprland = importApply ./profiles/graphical-hyprland {inherit localFlake;};
    profiles_graphical-niri = importApply ./profiles/graphical-niri {inherit localFlake;};
    profiles_server = importApply ./profiles/server.nix {inherit localFlake;};
    profiles_headless = importApply ./profiles/headless.nix {inherit localFlake;};
    profiles_minimal = importApply ./profiles/minimal.nix {inherit localFlake;};

    # -- programs --
    programs_bitwarden = importApply ./programs/bitwarden.nix {inherit localFlake;};

    programs_browsers_chromium = importApply ./programs/browsers/chromium.nix {inherit localFlake;};
    programs_browsers_firefox = importApply ./programs/browsers/firefox {inherit localFlake;};
    programs_browsers_vivaldi = importApply ./programs/browsers/vivaldi.nix {inherit localFlake;};
    programs_browsers_zen = importApply ./programs/browsers/zen-browser {inherit localFlake;};

    programs_btop = importApply ./programs/btop.nix {inherit localFlake;};
    programs_tmux = importApply ./programs/tmux.nix {inherit localFlake;};
    programs_zellij = importApply ./programs/zellij.nix {inherit localFlake;};
    programs_direnv = importApply ./programs/direnv.nix {inherit localFlake;};
    programs_dmenu = importApply ./programs/dmenu.nix {inherit localFlake;};
    programs_walker = importApply ./programs/walker.nix {inherit localFlake;};
    programs_wofi = importApply ./programs/wofi.nix {inherit localFlake;};
    programs_wlogout = importApply ./programs/wlogout.nix {inherit localFlake;};

    programs_editors_helix = importApply ./programs/editors/helix {inherit localFlake inputs;};
    programs_editors_zed = importApply ./programs/editors/zed {inherit localFlake inputs;};

    programs_file-managers_lf = importApply ./programs/file-managers/lf {inherit localFlake;};
    programs_file-managers_yazi = importApply ./programs/file-managers/yazi.nix {inherit localFlake;};
    # programs_file-managers_thunar = importApply ./programs/file-managers/thunar.nix {inherit localFlake;};

    programs_git = importApply ./programs/git.nix {inherit localFlake;};
    programs_jujutsu = importApply ./programs/jujutsu.nix {inherit localFlake;};
    programs_gpg = importApply ./programs/gpg.nix {inherit localFlake;};
    programs_ibtws = importApply ./programs/ib-tws.nix {
      inherit localFlake inputs;
      inherit secretsPath;
    };
    programs_newsboat = importApply ./programs/newsboat.nix {inherit localFlake;};
    programs_pywal = importApply ./programs/pywal.nix {inherit localFlake;};
    programs_ragenix = importApply ./programs/ragenix.nix {inherit localFlake inputs;};

    programs_shells_zsh = importApply ./programs/shells/zsh {inherit localFlake;};
    programs_shells_nushell = importApply ./programs/shells/nushell {inherit localFlake;};
    programs_shells_fish = importApply ./programs/shells/fish {inherit localFlake;};

    programs_ssh = importApply ./programs/ssh.nix {
      inherit secretsPath pubkeys;
      inherit localFlake;
    };
    programs_starship = importApply ./programs/starship.nix {inherit localFlake;};
    programs_terminals_alacritty = importApply ./programs/terminals/alacritty.nix {
      inherit localFlake;
    };
    programs_terminals_ghostty = importApply ./programs/terminals/ghostty/default.nix {
      inherit localFlake inputs;
    };
    # programs_terminals_kitty = importApply ./programs/terminals/kitty.nix {
    # inherit localFlake inputs;
    # };
    programs_terminals_foot = importApply ./programs/terminals/foot.nix {inherit localFlake;};
    # programs_thunderbird = importApply ./programs/thunderbird.nix {inherit localFlake;};

    programs_steam = importApply ./programs/games/steam.nix {inherit localFlake inputs;};
    programs_minecraft = importApply ./programs/games/minecraft.nix {inherit localFlake;};
    programs_wine = importApply ./programs/games/wine.nix {inherit localFlake;};
    # -- security --

    # -- services --
    # services_dunst = importApply ./services/dunst.nix {inherit localFlake;};
    services_swaync = importApply ./services/swaync {inherit localFlake;};
    # services_keepassxc = importApply ./services/keepassxc.nix {inherit localFlake;};
    services_pywalfox-native = importApply ./services/pywalfox-native.nix {
      inherit localFlake inputs;
    };
    services_x11_picom = importApply ./services/x11/picom.nix {inherit localFlake;};
    services_x11_redshift = importApply ./services/x11/redshift.nix {inherit localFlake;};

    # -- desktop --
    dektop_env_wayland = importApply ./desktop/environment/wayland.nix {inherit localFlake;};
    desktop_wayland_window-managers_hyprland =
      importApply ./desktop/window-managers/hyprland
      {inherit localFlake;};

    desktop_wayland_window-managers_niri =
      importApply ./desktop/window-managers/niri
      {inherit localFlake;};

    # -- system --
    system_impermanence = importApply ./system/impermanence.nix {inherit localFlake inputs;};

    # -- tasks --
  };
}
