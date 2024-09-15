{lib, ...}: let
  inherit (lib) mkEnableOption mkOption types mkImpermanenceEnableOption;
in {
  options.modules.system.programs.shells.nushell = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the nushell.
    '';

    # pywal = {
    #   enable = mkPywalEnableOption;
    # };

    impermanence = {
      enable = mkImpermanenceEnableOption;
    };

    withAutocompletions = mkOption {
      type = bool;
      default = true;
      description = ''
        Whether to enable autosuggestions/autocompletion related code
      '';
    };

    withAtuin = mkOption {
      type = bool;
      default = true;
      description = ''
        Whether to enable atuin related code
      '';
    };
    withZoxide = mkOption {
      type = bool;
      default = true;
      description = ''
        Whether to enable zoxide related code
      '';
    };

    shellAliases = {
      lsToEza = mkOption {
        type = bool;
        default = true;
        description = ''
          Enable predefined shell aliases
        '';
      };

      catToBat = mkOption {
        type = bool;
        default = true;
        description = ''
          Remap the cat related commands to its reworked edition bat.
        '';
      };

      findToFd = mkOption {
        type = bool;
        default = true;
        description = ''
          Remap the find related commands to its reworked edition fd.
        '';
      };

      grepToRipgrep = mkOption {
        type = bool;
        default = true;
        description = ''
          Remap the find related commands to its reworked edition fd.
        '';
      };
    };
  };
}
