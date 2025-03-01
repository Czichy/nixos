{localFlake}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  inherit
    (localFlake.lib)
    mkOverrideAtHmModuleLevel
    isModuleLoadedAndEnabled
    mkImpermanenceEnableOption
    ;

  cfg = config.tensorfiles.hm.services.keepassxc;
  _ = mkOverrideAtHmModuleLevel;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.hm.system.impermanence
    else {};
in {
  # TODO maybe use toINIWithGlobalSection generator? however the ini config file
  # also contains some initial keys? I should investigate this more
  options.tensorfiles.hm.services.keepassxc = with types; {
    enable = mkEnableOption ''
      TODO
    '';

    impermanence = {
      enable = mkImpermanenceEnableOption;
    };

    pkg = mkOption {
      type = package;
      default = pkgs.keepassxc;
      description = ''
        The package to use for keepassxc.
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      home.packages = [cfg.pkg];

      # systemd.user.services.keepassxc = {
      #   Unit = {
      #     Description = _ "KeePassXC password manager";
      #     After = [ "graphical-session-pre.target" ];
      #     PartOf = [ "graphical-session.target" ];
      #   };

      #   Install = {
      #     WantedBy = [ "graphical-session.target" ];
      #   };
      #   # TODO pkgs.keepassxc doesnt have a mainProgram for getExe set
      #   Service = {
      #     ExecStart = _ "${cfg.pkg}/bin/keepassxc";
      #   };
      # };
    }
    # |----------------------------------------------------------------------| #
    (mkIf impermanenceCheck {
      home.persistence."${impermanence.persistentRoot}${config.home.homeDirectory}" = {
        directories = [
          ".cache/keepassxc"
          ".config/keepassxc"
        ];
        files = [".mozilla/native-messaging-hosts/org.keepassxc.keepassxc_browser.json"];
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
