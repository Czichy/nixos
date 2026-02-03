{localFlake}: {
  pkgs,
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit
    (localFlake.lib)
    mkOverrideAtHmProfileLevel
    isModuleLoadedAndEnabled
    mkImpermanenceEnableOption
    ;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.hm.system.impermanence
    else {};

  cfg = config.tensorfiles.hm.profiles.graphical;
  _ = mkOverrideAtHmProfileLevel;
in {
  options.tensorfiles.hm.profiles.graphical = with types; {
    enable = mkEnableOption ''
      TODO
    '';

    impermanence = {
      enable = mkImpermanenceEnableOption;
    };
  };

  #imports = with inputs; [stylix.nixosModules.stylix];

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      tensorfiles.hm = {
        profiles.headless.enable = _ true;
        programs = {
          terminals.ghostty.enable = _ true;
          browsers = {
            vivaldi.enable = _ true;
            chromium.enable = _ true;
            zen-browser.enable = _ true;
          };
          editors.helix.enable = _ true;
        };
      };

      services.rsibreak.enable = _ false;

      home.packages = with pkgs; [
        ente-desktop
        libreoffice # Comprehensive, professional-quality productivity suite, a variant of openoffice.org
        # gitbutler # Git client for simultaneous branches on top of your existing workflow
        bruno # Open-source IDE For exploring and testing APIs

        mpv # General-purpose media player, fork of MPlayer and mplayer2
        zathura # A highly customizable and functional PDF viewer

        grim
        imv
        pulseaudio
        cliphist
        ydotool

        # -- FONTS PACKAGES --
        atkinson-hyperlegible # Sans serif for accessibility
        atkinson-monolegible
        corefonts # microsoft fonts
        eb-garamond # free garamond port
        ibm-plex # Striking Fonts from IBM
        iosevka
        jetbrains-mono # monospace
        lmodern # TeX font
        nerd-fonts.iosevka
        noto-fonts-color-emoji # emoji primary
        open-sans # nice sans
        unifont # bitmap font, good fallback
        unifont_upper # upper unicode ranges of unifont
        vollkorn # weighty serif
        noto-fonts # noto fonts: great for fallbacks

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

      fonts.fontconfig.enable = _ true;

      services.network-manager-applet.enable = _ true;
    }
    # |----------------------------------------------------------------------| #
    (mkIf impermanenceCheck {
      home.persistence."${impermanence.persistentRoot}" = {
        directories = [
          ".config/ente"
        ];
      };
    })
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
