{localFlake}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  cfg = config.tensorfiles.programs.file-managers.thunar;
in {
  options.tensorfiles.programs.file-managers.thunar = with types; {
    enable = mkEnableOption ''
      TODO
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      programs.thunar = {
        enable = true;
        plugins = with pkgs.xfce;
          mkDefault [
            thunar-volman
            thunar-dropbox-plugin
            thunar-archive-plugin
            thunar-media-tags-plugin
          ];
      };
    }
    # |----------------------------------------------------------------------| #
    {
      # # Tumbler for thumbnail support in Thunar
      services.tumbler.enable = mkDefault true;

      # GVFS for Mount, Trash, and other filesystem tools
      services.gvfs = {
        enable = mkDefault true;
        package = lib.mkForce pkgs.gnome.gvfs;
      };

      environment.systemPackages = with pkgs; [
        samba
        cifs-utils
      ];

      # # Samba Fix
      # networking.firewall.extraCommands = ''iptables -t raw -A OUTPUT -p udp -m udp --dport 137 -j CT --helper netbios-ns'';

      # Xfconf is needed to save thunar's preferences in case XFCE doesn't exist
      # TODO: Eventually pull this into its own module and use home manager for xfconf settings!
      programs.xfconf.enable = mkDefault true;
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
