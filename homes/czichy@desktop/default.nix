{pkgs, ...}: let
  homeDir = "/home/czichy";
in {
  tensorfiles.hm = {
    profiles.graphical-hyprland.enable = true;
    profiles.graphical-niri.enable = true;
    security.agenix.enable = true;

    system.impermanence = {
      enable = true;
      allowOther = true;
    };
    programs = {
      bitwarden.enable = true;
      ssh = {
        enable = true;
        sshKey.enable = false;
      };
      git.enable = true;
      ib-tws.enable = true;
      ragenix.enable = true;
      games = {
        steam.enable = true;
        minecraft.enable = true;
      };
      terminals.foot.makeDefault = true;
      editors.zed.enable = true;
    };
    hardware.monitors = {
      enable = true;
      monitors = [
        {
          name = "DP-2";
          width = 3840;
          height = 2160;
          hasBar = true;
          refreshRate = 60;
          x = 0;
          y = 0;
          scale = "1.0";
          primary = true;
          defaultWorkspace = 1;
        }

        {
          name = "DP-3";
          width = 3840;
          height = 2160;
          hasBar = true;
          refreshRate = 60;
          x = 3840;
          y = -867;
          scale = "1.0";
          primary = false;
          defaultWorkspace = 6;
          transform = 3;
        }
      ];
    };
  };

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = ["qemu:///system"];
      uris = ["qemu:///system"];
    };
  };

  home.username = "czichy";
  home.homeDirectory = homeDir;
  home.sessionVariables = {
    DEFAULT_USERNAME = "czichy";
    DEFAULT_MAIL = "christian@czichy.com";
    # Default programs
    BROWSER = "zen-beta";
    EXPLORER = "yazi";
    TERMINAL = "foot";
    EDITOR = "hx";
    LAUNCHER = "walker";
  };

  home.packages = with pkgs; [
  ];
}
