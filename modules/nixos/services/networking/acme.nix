{
  localFlake,
  secretsPath,
}: {
  config,
  lib,
  pkgs,
  hostName,
  ...
}:
with builtins;
with lib; let
  inherit
    (localFlake.lib)
    isModuleLoadedAndEnabled
    mkImpermanenceEnableOption
    mkAgenixEnableOption
    ;

  cfg = config.tensorfiles.services.networking.acme;
  _ = mkOverrideAtModuleLevel;

  agenixCheck = (isModuleLoadedAndEnabled config "tensorfiles.security.agenix") && cfg.agenix.enable;
in {
  # TODO move bluetooth dir to hardware
  options.tensorfiles.services.networking.acme = with types; {
    enable =
      mkEnableOption ''
      '';

    impermanence = {
      enable = mkImpermanenceEnableOption;
    };

    agenix = {
      enable = mkAgenixEnableOption;
    };

    wildcardDomains = mkOption {
      type = types.listOf types.str;
      default = ["czichy.com"];
      description = ''
        List of domains to which a wilcard certificate exists under the same name in `certs`.
        All of these certs will automatically have `*.<domain>` appended to `extraDomainNames`.
      '';
    };
  };

  options.services.nginx.virtualHosts = mkOption {
    type = types.attrsOf (types.submodule (submod: {
      options.useACMEWildcardHost = mkOption {
        type = types.bool;
        default = false;
        description = ''Automatically set useACMEHost with the correct wildcard domain for the virtualHosts's main domain.'';
      };
      config = let
        # This retrieves all matching wildcard certs that would include the corresponding domain.
        # If no such domain is found then an assertion is triggered.
        domain = submod.config._module.args.name;
        matchingCerts =
          if elem domain cfg.wildcardDomains
          then [domain]
          else
            filter
            (x: !hasInfix "." (removeSuffix ".${x}" domain))
            cfg.wildcardDomains;
      in
        mkIf submod.config.useACMEWildcardHost {
          useACMEHost = assert assertMsg (matchingCerts != []) "No wildcard certificate was defined that matches ${domain}";
            head matchingCerts;
        };
    }));
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      users.groups.acme.members = ["nginx" "caddy" "acme-sync"];
      security.acme = {
        acceptTerms = true;
        defaults = {
          email = "christian@czichy.com";
          credentialFiles = {
            CF_DNS_API_TOKEN_FILE = config.age.secrets.acme-cloudflare-dns-token.path;
            CF_ZONE_API_TOKEN_FILE = config.age.secrets.acme-cloudflare-zone-token.path;
          };
          dnsProvider = "cloudflare";
          dnsPropagationCheck = true;
          reloadServices = ["nginx" "caddy"];
        };
        # inherit (acme) certs wildcardDomains;
      };
    }
    # |----------------------------------------------------------------------| #
    {
      security.acme.certs = genAttrs cfg.wildcardDomains (domain: {
        extraDomainNames = ["*.${domain}"];
      });
    }
    # |----------------------------------------------------------------------| #
    (mkIf agenixCheck {
      age.secrets.acme-cloudflare-dns-token = {
        file = secretsPath + "/cloudflare/acme-cloudflare-dns-token.age";
        mode = "440";
        group = "acme";
      };

      age.secrets.acme-cloudflare-zone-token = {
        file = secretsPath + "/cloudflare/acme-cloudflare-dns-token.age";
        mode = "440";
        group = "acme";
      };
    })
    # |----------------------------------------------------------------------| #
  ]);
}
