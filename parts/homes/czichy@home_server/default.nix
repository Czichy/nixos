# --- parts/homes/czichy@jetbundle/default.nix
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
{pkgs, ...}: {
  tensorfiles.hm = {
    profiles.server.enable = true;
    security.agenix.enable = true;

    system.impermanence = {
      enable = true;
      allowOther = true;
    };
    programs = {
      ssh = {
        enable = true;
        sshKey.enable = false;
      };
      ragenix.enable = true;
    };
    # hardware.monitors = {
    #   enable = true;
    #   monitors = [
    #     {
    #       name = "DP-2";
    #       width = 3840;
    #       height = 2160;
    #       hasBar = true;
    #       refreshRate = 60;
    #       x = 0;
    #       y = 2160;
    #       scale = "1.0";
    #       primary = true;
    #       defaultWorkspace = 1;
    #     }

    #     {
    #       name = "DP-3";
    #       width = 3840;
    #       height = 2160;
    #       hasBar = true;
    #       refreshRate = 60;
    #       x = 0;
    #       y = 0;
    #       scale = "1.0";
    #       primary = false;
    #       defaultWorkspace = 6;
    #     }
    #   ];
    # };
  };

  home.username = "czichy";
  home.homeDirectory = "/home/czichy";
  home.sessionVariables = {
    DEFAULT_USERNAME = "czichy";
    DEFAULT_MAIL = "christian@czichy.com";
  };

  home.packages = with pkgs; [
    # NOTE: the packages below are typically part of a NixOS base installation
    # under root, hardware related utils should probably be installed manually
    # using the default package manager of the system instead of home-manager,
    # so those are omitted

    # --- BASE UTILS ---
    htop # An interactive process viewer
    jq # A lightweight and flexible command-line JSON processor
    killall
    vim # The most popular clone of the VI editor
    # neofetch # A fast, highly customizable system info script

    # ARCHIVING UTILS --
    atool # Archive command line helper
    gzip # GNU zip compression program
    lz4 # Extremely fast compression algorithm
    lzip # A lossless data compressor based on the LZMA algorithm
    lzop # Fast file compressor
    p7zip # A new p7zip fork with additional codecs and improvements (forked from https://sourceforge.net/projects/p7zip/)
    rar # Utility for RAR archives
    # unrar # Utility for RAR archives # NOTE collision with rar
    rzip # Compression program
    unzip # An extraction utility for archives compressed in .zip format
    xz # A general-purpose data compression software, successor of LZMA
    zip # Compressor/archiver for creating and modifying zipfiles
    zstd # Zstandard real-time compression algorithm

    # -- MISC --
    libarchive # Multi-format archive and compression library

    # -- NIX UTILS --
    nix-index # A files database for nixpkgs
    nix-du # A tool to determine which gc-roots take space in your nix store
    nix-inspect # A ranger-like TUI for inspecting your nixos config and other arbitrary nix expressions.
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
