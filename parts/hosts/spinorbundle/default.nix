# --- parts/hosts/spinorbundle/default.nix
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
{
  pkgs,
  inputs,
  system,
  ...
}:
{
  # -----------------
  # | SPECIFICATION |
  # -----------------
  # Model: Lenovo B51-80

  # --------------------------
  # | ROLES & MODULES & etc. |
  # --------------------------
  imports = with inputs; [
    disko.nixosModules.disko
    nix-gaming.nixosModules.pipewireLowLatency

    # TODO fails with The option `programs.steam.extraCompatPackages' in
    # `/nix/store/nra828scc8qs92b9pxra5csqzffb6hpl-source/nixos/modules/programs/steam.nix'
    # is already declared in
    # `/nix/store/cqapfi5bvhzvarrbi2h1qrf2dav5r1nd-source/flake.nix#nixosModules.steamCompat'.
    # nix-gaming.nixosModules.steamCompat
    ./hardware-configuration.nix
    ./disko.nix
  ];

  # ------------------------------
  # | ADDITIONAL SYSTEM PACKAGES |
  # ------------------------------
  environment.systemPackages = with pkgs; [
    libva-utils
    networkmanagerapplet # need this to configure L2TP ipsec
    docker-compose
    wireguard-tools
  ];

  # ----------------------------
  # | ADDITIONAL USER PACKAGES |
  # ----------------------------
  # home-manager.users.${user} = {home.packages = with pkgs; [];};

  # ---------------------
  # | ADDITIONAL CONFIG |
  # ---------------------
  tensorfiles = {
    profiles.graphical-plasma6.enable = true;
    profiles.packages-extra.enable = true;

    security.agenix.enable = true;
    programs.shadow-nix.enable = true;
    system.users.usersSettings."root" = {
      agenixPassword.enable = true;
    };
    system.users.usersSettings."czichy" = {
      isSudoer = true;
      isNixTrusted = true;
      agenixPassword.enable = true;
      extraGroups = [
        "video"
        "camera"
        "audio"
        "networkmanager"
        "input"
        "docker"
      ];
    };
  };

  programs.shadow-client.forceDriver = "iHD";
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  services = {
    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      jack.enable = true;
      lowLatency.enable = true;
    };
  };

  programs.steam.enable = true; # just trying it out

  networking.networkmanager.enable = true;
  networking.networkmanager.enableStrongSwan = true;
  services.xl2tpd.enable = true;
  services.strongswan = {
    enable = true;
    secrets = [ "ipsec.d/ipsec.nm-l2tp.secrets" ];
  };

  # Needed for gpg pinetry
  services.pcscd.enable = true;

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    storageDriver = "btrfs";
  };

  # NOTE for wireguard
  networking.wireguard.enable = true;
  networking.firewall = {
    allowedUDPPorts = [ 51820 ];
  };

  # If you intend to route all your traffic through the wireguard tunnel, the
  # default configuration of the NixOS firewall will block the traffic because
  # of rpfilter. You can either disable rpfilter altogether:
  networking.firewall.checkReversePath = false;

  home-manager.users."czichy" = {
    tensorfiles.hm = {
      profiles.graphical-plasma.enable = true;
      security.agenix.enable = true;

      services.keepassxc.enable = true;
    };

    services.syncthing = {
      enable = true;
      tray.enable = true;
    };

    home.username = "czichy";
    home.homeDirectory = "/home/czichy";
    home.sessionVariables = {
      DEFAULT_USERNAME = "czichy";
      DEFAULT_MAIL = "christian@czichy.com";
    };
    programs.git.signing.key = "3E83AD690FA4F657";

    home.packages = with pkgs; [
      thunderbird # A full-featured e-mail client
      beeper # Universal chat app.
      armcord # Lightweight, alternative desktop client for Discord
      anki # Spaced repetition flashcard program
      libreoffice # Comprehensive, professional-quality productivity suite, a variant of openoffice.org
      texlive.combined.scheme-full # TeX Live environment
      zotero # Collect, organize, cite, and share your research sources
      lapack # openblas with just the LAPACK C and FORTRAN ABI
      ungoogled-chromium # An open source web browser from Google, with dependencies on Google web services removed
      zoom-us # Player for Z-Code, TADS and HUGO stories or games

      slack # Desktop client for Slack
      signal-desktop # Private, simple, and secure messenger

      todoist # Todoist CLI Client
      todoist-electron # The official Todoist electron app

      mpv # General-purpose media player, fork of MPlayer and mplayer2
      zathura # A highly customizable and functional PDF viewer

      # inputs.nix-gaming.packages.${system}.osu-stable
      inputs.nix-gaming.packages.${system}.osu-lazer-bin
      inputs.self.packages.${system}.pywalfox-native
    ];
  };
}
