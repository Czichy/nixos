{pkgs, ...}: let
  homeDir = "/home/czichy";
in {
  tensorfiles.hm = {
    profiles.graphical-hyprland.enable = true;
    security.agenix.enable = true;

    system.impermanence = {
      enable = true;
      allowOther = true;
    };
    services.keepassxc.enable = true;
    programs = {
      bitwarden.enable = true;
      browsers.vivaldi.enable = true;
      browsers.zen-browser.enable = true;
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
          y = 2160;
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
          x = 0;
          y = 0;
          scale = "1.0";
          primary = false;
          defaultWorkspace = 6;
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
  };

  home.packages = with pkgs; [
    #thunderbird # A full-featured e-mail client
    #beeper # Universal chat app.
    #armcord # Lightweight, alternative desktop client for Discord
    #anki # Spaced repetition flashcard program
    libreoffice # Comprehensive, professional-quality productivity suite, a variant of openoffice.org
    #texlive.combined.scheme-medium # TeX Live environment
    #zotero # Collect, organize, cite, and share your research sources
    #lapack # openblas with just the LAPACK C and FORTRAN ABI
    #ungoogled-chromium # An open source web browser from Google, with dependencies on Google web services removed
    #zoom-us # Player for Z-Code, TADS and HUGO stories or games

    #slack # Desktop client for Slack
    #signal-desktop # Private, simple, and secure messenger

    #todoist # Todoist CLI Client
    #todoist-electron # The official Todoist electron app

    mpv # General-purpose media player, fork of MPlayer and mplayer2
    zathura # A highly customizable and functional PDF viewer

    # NOTE: the packages below are typically part of a NixOS base installation
    # under root, hardware related utils should probably be installed manually
    # using the default package manager of the system instead of home-manager,
    # so those are omitted

    # --- BASE UTILS ---
    htop # An interactive process viewer
    jq # A lightweight and flexible command-line JSON processor
    killall
    vim # The most popular clone of the VI editor
    pavucontrol # volume control

    # ARCHIVING UTILS --
    atool # Archive command line helper
    gzip # GNU zip compression program
    lz4 # Extremely fast compression algorithm
    lzip # A lossless data compressor based on the LZMA algorithm
    lzop # Fast file compressor
    p7zip # A new p7zip fork with additional codecs and improvements (forked from https://sourceforge.net/projects/p7zip/)
    rar # Utility for RAR archives
    # unrar # Utility for RAR archives # NOTE collision with rar
    # rzip # Compression program
    unzip # An extraction utility for archives compressed in .zip format
    xz # A general-purpose data compression software, successor of LZMA
    zip # Compressor/archiver for creating and modifying zipfiles
    zstd # Zstandard real-time compression algorithm

    # -- MISC --
    libarchive # Multi-format archive and compression library

    # -- NIX UTILS --
    nix-index # A files database for nixpkgs
    nix-du # A tool to determine which gc-roots take space in your nix store
    nix-tree # Interactively browse a Nix store paths dependencies
    nix-health # Check the health of your Nix setup
    nix-update # Swiss-knife for updating nix packages
    # nix-serve # A utility for sharing a Nix store as a binary cache # NOTE conflict with serve-ng
    nix-serve-ng # A drop-in replacement for nix-serve that's faster and more stable
    nix-prefetch-scripts # Collection of all the nix-prefetch-* scripts which may be used to obtain source hashes
    nix-output-monitor # Processes output of Nix commands to show helpful and pretty information
    nh # Yet another nix cli helper
    disko # Declarative disk partitioning and formatting using nix
  ];
}
