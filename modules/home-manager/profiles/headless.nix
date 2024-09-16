# --- parts/modules/home-manager/profiles/headless.nix
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
{ localFlake }:
{ config, lib, ... }:
with builtins;
with lib;
let
  inherit (localFlake.lib)
    mkOverrideAtHmProfileLevel
    isModuleLoadedAndEnabled
    mkImpermanenceEnableOption
    ;

  cfg = config.tensorfiles.hm.profiles.headless;
  _ = mkOverrideAtHmProfileLevel;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.system.impermanence") && cfg.impermanence.enable;
  impermanence = if impermanenceCheck then config.tensorfiles.hm.system.impermanence else { };
  pathToRelative = strings.removePrefix "${config.home.homeDirectory}/";
in
{
  options.tensorfiles.hm.profiles.headless = with types; {
    enable = mkEnableOption ''
      TODO
    '';

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
          shells.nushell.enable = _ true;
          starship.enable = _ true;
          editors.helix.enable = _ true;
          file-managers.yazi.enable = _ true;

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

  meta.maintainers = with localFlake.lib.maintainers; [ czichy ];
}
