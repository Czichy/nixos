{
  localFlake,
  secretsPath,
  pubkeys,
}: {
  config,
  lib,
  hostName,
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

  cfg = config.tensorfiles.hm.programs.ssh;
  _ = mkOverrideAtHmModuleLevel;

  sshKeyCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.security.agenix") && cfg.sshKey.enable;
  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.hm.system.impermanence
    else {};
in {
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
        enableDefaultConfig = _ false;
      };

      programs.keychain = {
        enable = _ true;
        enableBashIntegration = _ (isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.bash");
        enableZshIntegration = _ (isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.zsh");
        enableFishIntegration = _ (isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.fish");
        enableNushellIntegration = _ (
          isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.nushell"
        );
        # agents = ["ssh"];
        extraFlags = [
          "--nogui"
          "--quiet"
        ];
        keys = ["id_ed25519"];
      };

      services.ssh-agent.enable = _ true;
    }
    # |----------------------------------------------------------------------| #
    (mkIf sshKeyCheck {
      age.secrets."${cfg.sshKey.privateKeySecretsPath}" = {
        file = _ (secretsPath + "/${cfg.sshKey.privateKeySecretsPath}.age");
        mode = _ "700";
      };
      home.file = with cfg.sshKey; {
        "${privateKeyHomePath}".source = _ (
          config.lib.file.mkOutOfStoreSymlink config.age.secrets."${privateKeySecretsPath}".path
        );

        "${publicKeyHomePath}".text = let
          key =
            if publicKeyRaw != null
            then publicKeyRaw
            else
              #(attrsets.attrByPath (replaceStrings [ "$user" ] [ config.home.username ] (
              #  splitString "." publicKeySecretsAttrsetKey
              #)) "" pubkeys);
              (attrsets.attrByPath (splitString "." (
                  replaceStrings ["$user"] [config.home.username] publicKeySecretsAttrsetKey
                )) ""
                pubkeys);
        in
          _ key;
      };
    })
    # |----------------------------------------------------------------------| #
    {
      home.persistence."${impermanence.persistentRoot}" = {
        directories = [".ssh"];
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
