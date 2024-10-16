# --- parts/modules/home-manager/programs/ssh.nix
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
  localFlake,
  secretsPath,
  pubkeys,
}:
{
  config,
  lib,
  hostName,
  ...
}:
with builtins;
with lib;
let
  inherit (localFlake.lib)
    mkOverrideAtHmModuleLevel
    isModuleLoadedAndEnabled
    mkImpermanenceEnableOption
    ;

  cfg = config.tensorfiles.hm.programs.ssh;
  _ = mkOverrideAtHmModuleLevel;

  sshKeyCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.security.agenix") && cfg.sshKey.enable;
  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.system.impermanence") && cfg.impermanence.enable;
  impermanence = if impermanenceCheck then config.tensorfiles.hm.system.impermanence else { };
in
{
  options.tensorfiles.hm.programs.ssh = with types; {
    enable = mkEnableOption ''
      TODO
    '';
    impermanence = {
      enable = mkImpermanenceEnableOption;
    };

    sshKey = {
      enable = mkEnableOption ''
        TODO
      '';

      privateKeySecretsPath = mkOption {
        type = str;
        default = "hosts/${hostName}/users/${config.home.username}/private_key";
        description = ''
          TODO
        '';
      };

      privateKeyHomePath = mkOption {
        type = str;
        default = ".ssh/id_ed25519";
        description = ''
          TODO
        '';
      };

      publicKeyHomePath = mkOption {
        type = str;
        default = ".ssh/id_ed25519.pub";
        description = ''
          TODO
        '';
      };

      publicKeyRaw = mkOption {
        type = nullOr str;
        default = null;
        description = ''
          TODO
        '';
      };

      publicKeySecretsAttrsetKey = mkOption {
        type = str;
        default = "hosts.${hostName}.users.$user.sshKey";
        description = ''
          TODO
        '';
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      programs.ssh = {
        enable = _ true;
      };

      programs.keychain = {
        enable = _ true;
        enableBashIntegration = _ (isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.bash");
        enableZshIntegration = _ (isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.zsh");
        enableFishIntegration = _ (isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.fish");
        enableNushellIntegration = _ (
          isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.nushell"
        );
        agents = [ "ssh" ];
        extraFlags = [
          "--nogui"
          "--quiet"
        ];
        keys = [ "id_ed25519" ];
      };

      services.ssh-agent.enable = _ true;
    }
    # |----------------------------------------------------------------------| #
    (mkIf sshKeyCheck {
      age.secrets."${cfg.sshKey.privateKeySecretsPath}" = {
        file = _ (secretsPath + "/${cfg.sshKey.privateKeySecretsPath}.age");
        mode = _ "700";
        #owner = _ config.home.username;
      };
      home.file = with cfg.sshKey; {
        "${privateKeyHomePath}".source = _ (
          config.lib.file.mkOutOfStoreSymlink config.age.secrets."${privateKeySecretsPath}".path
        );

        "${publicKeyHomePath}".text =
          let
            key =
              if publicKeyRaw != null then
                publicKeyRaw
              else
                #(attrsets.attrByPath (replaceStrings [ "$user" ] [ config.home.username ] (
                #  splitString "." publicKeySecretsAttrsetKey
                #)) "" pubkeys);
                (attrsets.attrByPath (splitString "." (
                  replaceStrings [ "$user" ] [ config.home.username ] publicKeySecretsAttrsetKey
                )) "" pubkeys);
          in
          _ key;
      };
    })
    # |----------------------------------------------------------------------| #
    {
      home.persistence."${impermanence.persistentRoot}${config.home.homeDirectory}" = {
        #  home.persistence."/persist/home/czichy" = {
        directories = [ ".ssh" ];
        #    #files = [ ".ssh/known_hosts" ];
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [ czichy ];
}
