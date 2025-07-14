{
  localFlake,
  inputs,
}: {
  config,
  lib,
  pkgs,
  system,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtProfileLevel;

  cfg = config.tensorfiles.profiles.packages-extra;
  _ = mkOverrideAtProfileLevel;
in {
  options.tensorfiles.profiles.packages-extra = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the packages-extra system profile.

      **Packages-Extra layer**
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      environment.systemPackages = with pkgs;
        [
          # --- BASE UTILS ---
          binutils # Tools for manipulating binaries (linker, assembler, etc.) (wrapper script)
          htop # An interactive process viewer
          jq # A lightweight and flexible command-line JSON processor
          killall
          #vim # The most popular clone of the VI editor
          # calcurse # A calendar and scheduling application for the command line
          #w3m # A text-mode web browser
          # neofetch # A fast, highly customizable system info script
          #cmake # Cross-platform, open-source build system generator
          #gnumake # A tool to control the generation of non-source files from sources
          git # Distributed version control system
          gitoxide #An idiomatic, lean, fast & safe pure Rust implementation of Git
          gitui # Blazing 💥 fast terminal-ui for git written in rust 🦀

          # --- APPLICATIONS ---
          # nautilus
          nemo-with-extensions

          # --- NET UTILS ---
          dig # Domain name server
          netcat # Free TLS/SSL implementation
          wget # Tool for retrieving files using HTTP, HTTPS, and FTP
          curl # A command line tool for transferring files with URL syntax
          nmap # A free and open source utility for network discovery and security auditing

          # --- HW UTILS ---
          dosfstools # Utilities for creating and checking FAT and VFAT file systems
          #exfatprogs # exFAT filesystem userspace utilities
          udisks # A daemon, tools and libraries to access and manipulate disks, storage devices and technologies
          pciutils # A collection of programs for inspecting and manipulating configuration of PCI devices
          usbutils # Tools for working with USB devices, such as lsusb
          iotop # A tool to find out the processes doing the most IO
          hw-probe # Probe for hardware, check operability and find drivers
          ntfs3g # FUSE-based NTFS driver with full write support

          # -- ARCHIVING UTILS --
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
          #sqlite # A self-contained, serverless, zero-configuration, transactional SQL database engine
          #sqlitebrowser # DB Browser for SQLite
          libarchive # Multi-format archive and compression library
          libbtbb # Bluetooth baseband decoding library
          #adminer # Database management in a single PHP file

          # -- PACKAGING UTILS --
          # nix-ld # Run unpatched dynamic binaries on NixOS
          appimage-run # Run unpatched AppImages on NixOS
          libappimage # Implements functionality for dealing with AppImage files

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
          nixos-shell # Spawns lightweight nixos vms in a shell
          deploy-rs # Multi-profile Nix-flake deploy tool
          nh # Yet another nix cli helper
          disko # Declarative disk partitioning and formatting using nix
          cachix # Command-line client for Nix binary cache hosting https://cachix.org
          devenv # Fast, Declarative, Reproducible, and Composable Developer Environments
        ]
        ++ [
          inputs.nix-alien.packages.${system}.nix-alien # Run unpatched binaries on Nix/NixOS
        ];

      programs.nix-ld.enable = _ true; # Run unpatched dynamic binaries on NixOS
      programs.fish.enable = _ true; # Run unpatched dynamic binaries on NixOS
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
