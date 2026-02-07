{localFlake,secretsPath}: {
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib)
  mkOverrideAtHmModuleLevel
  mkImpermanenceEnableOption
  isModuleLoadedAndEnabled
    mkAgenixEnableOption;

  cfg = config.tensorfiles.hm.programs.thunderbird;
  _ = mkOverrideAtHmModuleLevel;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.hm.system.impermanence
    else {};

  agenixCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.security.agenix") && cfg.agenix.enable;
in {
  options.tensorfiles.hm.programs.thunderbird = with types; {
    enable = mkEnableOption ''
      TODO
    '';

    impermanence = {
      enable = mkImpermanenceEnableOption;
    };
    agenix = {
      enable = mkAgenixEnableOption;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      accounts.email.accounts = {
      default = {
              primary = true;
              realName = "Christian Czichy";
              address = "christian@czichy.com";
              imap = {
                        host = "imap.ionos.de";
                        tls.enable = true;
                      };
                      smtp = {
                        host = "smtp.ionos.de";
                        port = 587;
                      };
              signature = {
                        text = ''
                          Christian Czichy
                        '';
                        showSignature = "append";
                      };

              userName = "christian@czichy.com";
              passwordCommand = "${pkgs.coreutils}/bin/cat ${config.age.secrets."christian@czichy.com".path}";
              folders.inbox = "virtual.all";
          thunderbird = {
            enable = true;
            profiles = ["default"];
          };
            };
      };
    }
    # |----------------------------------------------------------------------| #
    {
      programs.thunderbird = {
        enable = _ true;
        profiles.default = {
          isDefault = _ true;
          withExternalGnupg = true;

                settings = {
                  "mail.identity.default.archive_enabled" = true;
                  "mail.identity.default.archive_keep_folder_structure" = true;
                  "mail.identity.default.compose_html" = false;
                  "mail.identity.default.protectSubject" = true;
                  "mail.identity.default.reply_on_top" = 1;
                  "mail.identity.default.sig_on_reply" = false;

                  "gfx.webrender.all" = true;
                  "gfx.webrender.enabled" = true;

                  "browser.display.use_system_colors" = true;
                  "browser.theme.dark-toolbar-theme" = true;
                };
              };

              settings = {
                # Some general settings.
                "mail.server.default.allow_utf8_accept" = true;
                "mail.server.default.max_articles" = 1000;
                "mail.server.default.check_all_folders_for_new" = true;
                "mail.show_headers" = 1;

                # Show some metadata.
                "mailnews.headers.showMessageId" = true;
                "mailnews.headers.showOrganization" = true;
                "mailnews.headers.showReferences" = true;
                "mailnews.headers.showUserAgent" = true;

                # Sort mails and news in descending order.
                "mailnews.default_sort_order" = 2;
                "mailnews.default_news_sort_order" = 2;
                # Sort mails and news by date.
                "mailnews.default_sort_type" = 18;
                "mailnews.default_news_sort_type" = 18;

                # Sort them by the newest reply in thread.
                "mailnews.sort_threads_by_root" = true;
                # Show time.
                "mail.ui.display.dateformat.default" = 1;
                # Sanitize it to UTC to prevent leaking local time.
                "mail.sanitize_date_header" = true;

                # Email composing QoL.
                "mail.identity.default.auto_quote" = true;
                "mail.identity.default.attachPgpKey" = true;

                "app.update.auto" = false;
                "privacy.donottrackheader.enabled" = true;
        };
      };
    }
    # |----------------------------------------------------------------------| #
    (
      mkIf agenixCheck
      {
        age.secrets =  {
          "christian@czichy.com" = {
            file = _ (secretsPath + "/hosts/HL-1-OZ-PC-01/users/czichy/mail/christianatczichycom.age");
            mode = _ "0600";
          };
        };
      }
    )
    # |----------------------------------------------------------------------| #
    (mkIf impermanenceCheck {
      home.persistence."${impermanence.persistentRoot}" = {
        directories = [
        ".cache/thunderbird"
        ".thunderbird"
        ];
      };
    })
    # |----------------------------------------------------------------------| #
    {
      xdg.mimeApps.defaultApplications = {
        "x-scheme-handler/mailto" = [ "thunderbird.desktop" ];
        "x-scheme-handler/mid" = [ "thunderbird.desktop" ];
        "message/rfc822" = [ "thunderbird.desktop" ];
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
