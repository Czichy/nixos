{
  localFlake,
  secretsPath,
  pubkeys,
}: {
  config,
  lib,
  globals,
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

    extraMatchBlocks = mkOption {
      type = attrsOf anything;
      default = {};
      description = ''
        Zusätzliche SSH matchBlocks, die zu den auto-generierten Host-Einträgen
        aus globals.net hinzugefügt werden (z.B. externe Server oder git-Hosts).
      '';
    };
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

        matchBlocks = let
          # "10.15.40.0/24" → "10.15.40."
          cidrToPrefix = cidr:
            (lib.concatStringsSep "." (lib.take 3 (lib.splitString "." cidr))) + ".";

          # Alle Hosts aus allen VLANs sammeln; erstes Auftreten gewinnt bei Duplikaten.
          # builtins.tryEval fängt Fehler ab wenn ein VLAN im Modul-System eine
          # hosts-Option hat, diese aber keinen Wert hat (z.B. vlan60/IoT).
          autoMatchBlocks = lib.foldlAttrs (acc: _vlanName: vlan:
            let
              cidrResult = builtins.tryEval (vlan.cidrv4 or null);
              hostsResult = builtins.tryEval (vlan.hosts or {});
              cidr = if cidrResult.success then cidrResult.value else null;
              hosts = if hostsResult.success then hostsResult.value else {};
            in
              if cidr == null || hosts == {}
              then acc
              else
                let
                  prefix = cidrToPrefix cidr;
                  entries = lib.mapAttrs (_hostName: hostCfg: {
                    hostname = prefix + toString hostCfg.id;
                    user = "root";
                    extraOptions.StrictHostKeyChecking = "accept-new";
                  }) hosts;
                in
                  # acc hat Vorrang (erstes VLAN gewinnt)
                  entries // acc
          ) {} globals.net;
        in
          autoMatchBlocks // cfg.extraMatchBlocks;
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
