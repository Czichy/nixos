{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  inherit (lib) mkIf;
  inherit (config.age) secrets;

  sys = config.modules.system;
  cfg = sys.services;
in {
  imports = [
    inputs.simple-nixos-mailserver.nixosModule
  ];

  config = mkIf cfg.mailserver.enable {
    # required for roundcube
    networking.firewall.allowedTCPPorts = [80 443];

    mailserver = {
      enable = true;
      fqdn = "mail.czichy.dev";
      certificateScheme = "acme-nginx";
      domains = ["czichy.dev"];

      mailDirectory = "/srv/storage/mail/vmail";
      dkimKeyDirectory = "/srv/storage/mail/dkim";
      sieveDirectory = "/srv/storage/mail/sieve";

      # Ports & Security
      enableImap = true;
      enableImapSsl = true;
      enablePop3 = false;
      enablePop3Ssl = false;
      enableSubmission = false;
      enableSubmissionSsl = true;

      hierarchySeparator = "/";
      localDnsResolver = false;
      lmtpSaveToDetailMailbox = "yes";
      maxConnectionsPerUser = 25;
      loginAccounts = {
        "raf@czichy.dev" = {
          hashedPasswordFile = secrets.mailserver-secret.path;
          aliases = [
            "me@czichy.dev"
            "admin@czichy.dev"
            "root@czichy.dev"
            "postmaster@czichy.dev"
          ];
        };

        "noreply@czichy.dev" = {
          hashedPasswordFile = secrets.mailserver-noreply-secret.path;
          sendOnly = true;
          sendOnlyRejectMessage = "";
          quota = "1G";
        };

        "forgejo@czichy.dev" = mkIf cfg.forgejo.enable {
          aliases = ["git@czichy.dev"];
          hashedPasswordFile = secrets.mailserver-forgejo-secret.path;
          sendOnly = true;
          sendOnlyRejectMessage = "";
          quota = "1G";
        };

        "vaultwarden@czichy.dev" = mkIf cfg.vaultwarden.enable {
          aliases = ["vault@czichy.dev"];
          hashedPasswordFile = secrets.mailserver-vaultwarden-secret.path;
          sendOnly = true;
          sendOnlyRejectMessage = "";
          quota = "1G";
        };

        "matrix@czichy.dev" = mkIf cfg.social.matrix.enable {
          hashedPasswordFile = secrets.mailserver-matrix-secret.path;
          sendOnly = true;
          sendOnlyRejectMessage = "";
          quota = "1G";
        };

        "cloud@czichy.dev" = mkIf cfg.nextcloud.enable {
          aliases = ["nextcloud@czichy.dev"];
          hashedPasswordFile = secrets.mailserver-cloud-secret.path;
          sendOnly = true;
          sendOnlyRejectMessage = "";
          quota = "1G";
        };
      };

      mailboxes = {
        Archive = {
          auto = "subscribe";
          specialUse = "Archive";
        };

        Drafts = {
          auto = "subscribe";
          specialUse = "Drafts";
        };

        Sent = {
          auto = "subscribe";
          specialUse = "Sent";
        };

        Junk = {
          auto = "subscribe";
          specialUse = "Junk";
        };

        Trash = {
          auto = "no";
          specialUse = "Trash";
        };
      };

      fullTextSearch = {
        enable = true;
        # index new email as they arrive
        autoIndex = true;
        # this only applies to plain text attachments, binary attachments are never indexed
        indexAttachments = true;
        enforced = "body";
      };

      vmailUserName = "vmail";
      vmailGroupName = "vmail";

      useFsLayout = true;
    };

    services = {
      roundcube = {
        enable = true;
        database.username = "roundcube";
        maxAttachmentSize = 50;
        dicts = with pkgs.aspellDicts; [en tr de];
        # this is the url of the vhost, not necessarily the same as the fqdn of
        # the mailserver
        hostName = "webmail.czichy.dev";
        extraConfig = ''
          $config['imap_host'] = array(
            'tls://mail.czichy.dev' => "NotAShelf's Mail Server",
            'ssl://imap.gmail.com:993' => 'Google Mail',
          );
          $config['username_domain'] = array(
            'mail.czichy.dev' => 'czichy.dev',
            'mail.gmail.com' => 'gmail.com',
          );
          $config['x_frame_options'] = false;
          # starttls needed for authentication, so the fqdn required to match
          # the certificate
          $config['smtp_host'] = "tls://${config.mailserver.fqdn}";
          $config['smtp_user'] = "%u";
          $config['smtp_pass'] = "%p";
          $config['plugins'] = [ "carddav" ];
        '';
      };

      postfix = {
        dnsBlacklists = [
          "all.s5h.net"
          "b.barracudacentral.org"
          "bl.spamcop.net"
          "blacklist.woody.ch"
        ];
        dnsBlacklistOverrides = ''
          czichy.dev OK
          mail.czichy.dev OK
          127.0.0.0/8 OK
          192.168.0.0/16 OK
        '';
        headerChecks = [
          {
            action = "IGNORE";
            pattern = "/^User-Agent.*Roundcube Webmail/";
          }
        ];

        config = {
          smtp_helo_name = config.mailserver.fqdn;
        };
      };

      phpfpm.pools.roundcube.settings = {
        "listen.owner" = config.services.nginx.user;
        "listen.group" = config.services.nginx.group;
      };

      nginx.virtualHosts = {
        "mail.czichy.dev" = {quic = true;} // lib.sslTemplate;
        "webmail.czichy.dev" = {quic = true;} // lib.sslTemplate;
      };
    };
  };
}
