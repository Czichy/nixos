{localFlake}: {
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

  cfg = config.tensorfiles.hm.profiles.headless;
  _ = mkOverrideAtHmProfileLevel;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.hm.system.impermanence
    else {};
  pathToRelative = strings.removePrefix "${config.home.homeDirectory}/";
in {
  options.tensorfiles.hm.profiles.headless = with types; {
    enable = mkEnableOption ''
      TODO
    '';

    setHomeDirectories = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        set up home directories
      '';
    };

    impermanence = {
      enable = mkImpermanenceEnableOption;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      tensorfiles.hm = {
        profiles.minimal.enable = _ true;

        programs = {
          terminals.foot.enable = _ true;
          jujutsu.enable = _ true;
          shells.nushell.enable = _ true;
          # starship.enable = _ true;
          shells.fish.enable = _ true;
          editors.helix.enable = _ true;
          file-managers.yazi.enable = _ true;
          fastfetch.enable = _ true;
          starship.enable = _ true;

          btop.enable = _ true;
          zellij.enable = _ true;
          direnv.enable = _ true;
          git.enable = _ true;
          ssh.enable = _ true;
          ragenix.enable = _ true;
        };
      };

      home.sessionVariables = {
        # Default programs
        EDITOR = "hx";
        VISUAL = "hx";
        # Directory structure
        DOWNLOADS_DIR = config.home.homeDirectory + "/Downloads";
        ORG_DIR = config.home.homeDirectory + "/OrgBundle";
        PROJECTS_DIR = config.home.homeDirectory + "/projects";
        TRADING_DIR = config.home.homeDirectory + "/Trading";
        DOCUMENTS_DIR = config.home.homeDirectory + "/Dokumente";
        SECRETS_DIR = config.home.homeDirectory + "/.credentials";
        # Fallbacks
        # DEFAULT_USERNAME = "czichy";
        # DEFAULT_MAIL = "christian@czichy.com";
      };

      home.file = {
        #"${config.xdg.configHome}/.blank".text = mkBefore "";
        #"${config.xdg.cacheHome}/.blank".text = mkBefore "";
        #"${config.xdg.dataHome}/.blank".text = mkBefore "";
        #"${config.xdg.stateHome}/.blank".text = mkBefore "";
        #"${config.home.sessionVariables.DOWNLOADS_DIR}/.blank".text = mkIf (
        #  config.home.sessionVariables.DOWNLOADS_DIR != null
        #) (mkBefore "");
        #"${config.home.sessionVariables.ORG_DIR}/.blank".text = mkIf (
        #  config.home.sessionVariables.ORG_DIR != null
        #) (mkBefore "");
        #"${config.home.sessionVariables.PROJECTS_DIR}/.blank".text = mkIf (
        #  config.home.sessionVariables.PROJECTS_DIR != null
        #) (mkBefore "");
        #"${config.home.sessionVariables.TRADING_DIR}/.blank".text = mkIf (
        #  config.home.sessionVariables.TRADING_DIR != null
        #) (mkBefore "");
      };
    }
    # |----------------------------------------------------------------------| #
    {
      # systemd.user.tmpfiles.rules = [
      #   "d ${config.home.sessionVariables.TRADING_DIR} 0775 czichy rslsync -" # create directory for Resilio Sync files
      #   "d ${config.home.sessionVariables.DOCUMENTS_DIR} 0775 czichy rslsync -" # create directory for Resilio Sync files
      # ];
    }
    # |----------------------------------------------------------------------| #
    (mkIf impermanenceCheck {
      home.persistence."${impermanence.persistentRoot}${config.home.homeDirectory}" = {
        directories = [
          #".gnupg"
          ".ssh"
          #(pathToRelative config.home.sessionVariables.DOWNLOADS_DIR)
          #(pathToRelative config.home.sessionVariables.ORG_DIR)
          (pathToRelative config.home.sessionVariables.PROJECTS_DIR)
          (pathToRelative config.home.sessionVariables.TRADING_DIR)
          (pathToRelative config.home.sessionVariables.DOCUMENTS_DIR)
          (pathToRelative config.home.sessionVariables.SECRETS_DIR)
        ];
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
