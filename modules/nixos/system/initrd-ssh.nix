{
  localFlake,
  pubkeys,
}: {
  config,
  lib,
  pkgs,
  inputs,
  hostName,
  ...
}:
with builtins;
with lib; let
  cfg = config.tensorfiles.system.initrd-ssh;
in {
  options.tensorfiles.system.initrd-ssh = with types; {
    enable = lib.mkOption {
      type = bool;
      default = false;
      description = ''
        enable custom disk configuration
      '';
    };

    genHostKey = {
      enable = lib.mkEnableOption ''
        Enables autogenerating per-host based keys. Apart from certain additional
        checks this works mostly as a passthrough to
        `openssh.authorizedKeys.keys`, for more info refer to the documentation
        of said option.
      '';

      hostKey = lib.mkOption {
        type = lib.attrs;
        default = {
          type = "ed25519";
          path = "/persist/etc/ssh/ssh_host_ed25519_key";
        };
        description = ''
          TODO
        '';
      };
    };
    # authorizedKeys = {
    #   enable =
    #     mkEnableOption ''
    #       TODO
    #     ''
    #     // {
    #       default = true;
    #     };

    #   keysRaw = mkOption {
    #     type = listOf str;
    #     default = [];
    #     description = ''
    #       TODO
    #     '';
    #   };

    #   keysSecretsAttrsetKey = mkOption {
    #     type = str;
    #     default = "hosts.${hostName}.users.${_user}.authorizedKeys";
    #     description = ''
    #       TODO
    #     '';
    #   };
    # };
  };
  config = lib.mkMerge [
    # |----------------------------------------------------------------------| #
    (lib.mkIf cfg.enable {
      # age.secrets.initrd_host_ed25519_key.generator.script = "ssh-ed25519";

      # boot.kernelParams = ["ip=1.2.3.4::1.2.3.1:255.255.255.192:myhostname:enp35s0:off"];
      boot.initrd = {
        availableKernelModules = ["r8169" "igc"];
        systemd.users.root.shell = lib.mkForce "/bin/cryptsetup-askpass";
        # systemd.users.root.shell = "/bin/systemd-tty-ask-password-agent";
        network = {
          enable = true;
          ssh = {
            enable = true;
            port = 4;
            # this is the default
            authorizedKeys = pubkeys.czichy ++ pubkeys.recovery_key ++ pubkeys.HL-1-OZ-PC-01;
            hostKeys = ["/nix/secret/initrd/ssh_host_ed25519_key"];
            # hostKeys = [config.age.secrets.initrd_host_ed25519_key.path];
          };
        };
      };
      # Make sure that there is always a valid initrd hostkey available that can be installed into
      # the initrd. When bootstrapping a system (or re-installing), agenix cannot succeed in decrypting
      # whatever is given, since the correct hostkey doesn't even exist yet. We still require
      # a valid hostkey to be available so that the initrd can be generated successfully.
      # The correct initrd host-key will be installed with the next update after the host is booted
      # for the first time, and the secrets were rekeyed for the the new host identity.
      # system.activationScripts.agenixEnsureInitrdHostkey = {
      #   text = ''
      #     [[ -e ${config.age.secrets.initrd_host_ed25519_key.path} ]] \
      #       || ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -f ${config.age.secrets.initrd_host_ed25519_key.path}
      #   '';
      #   deps = ["agenixInstall" "users"];
      # };
      # system.activationScripts.agenixChown.deps = ["agenixEnsureInitrdHostkey"];
    })
    # |----------------------------------------------------------------------| #
    {
      # boot.kernelParams = ["ip=1.2.3.4::1.2.3.1:255.255.255.192:myhostname:enp35s0:off"];
      # networking = {
      #   useDHCP = false;
      #   interfaces."enp35s0" = {
      #     ipv4.addresses = [
      #       {
      #         address = "1.2.3.4";
      #         prefixLength = 26;
      #       }
      #     ];
      #     ipv6.addresses = [
      #       {
      #         address = "2a01:xx:xx::1";
      #         prefixLength = 64;
      #       }
      #     ];
      #   };
      #   defaultGateway = "1.2.3.1";
      #   defaultGateway6 = {
      #     address = "fe80::1";
      #     interface = "enp35s0";
      #   };
      # };
    }
    # |----------------------------------------------------------------------| #
  ];
}
