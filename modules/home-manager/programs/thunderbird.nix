{
  localFlake,
  secretsPath,
}: {
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
    mkImpermanenceEnableOption
    isModuleLoadedAndEnabled
    mkAgenixEnableOption
    ;

  cfg = config.tensorfiles.hm.programs.thunderbird;
  _ = mkOverrideAtHmModuleLevel;

  # ---------------------------------------------------------------------------
  # Radicale CalDAV/CardDAV – Deklarative Kalender-Konfiguration
  # ---------------------------------------------------------------------------
  # Thunderbird speichert Kalender in calendar.registry.<id>.* Prefs.
  # Wir nutzen deterministische IDs damit die Konfiguration idempotent ist.
  #
  # Nach dem ersten Start muss das Passwort einmalig in Thunderbird eingegeben
  # werden – es wird dann im Thunderbird-Passwort-Manager gespeichert.
  radicaleUrl = "https://cal.czichy.com";
  radicaleUser = "christian";

  # Deterministische Kalender-IDs (stabil über Rebuilds hinweg)
  calId = "a1b2c3d4-radicale-cal";
  contactsId = "a1b2c3d4-radicale-contacts";

  # Hilfsfunktion: Erzeugt alle calendar.registry.<id>.* Prefs für einen Kalender
  mkCalendarPrefs = {
    id,
    name,
    uri,
    color ? "#3366cc",
    isDefault ? false,
    refreshInterval ? 5,
    calType ? "caldav",
  }: {
    "calendar.registry.${id}.type" = calType;
    "calendar.registry.${id}.uri" = uri;
    "calendar.registry.${id}.name" = name;
    "calendar.registry.${id}.color" = color;
    "calendar.registry.${id}.username" = radicaleUser;
    "calendar.registry.${id}.disabled" = false;
    "calendar.registry.${id}.readOnly" = false;
    "calendar.registry.${id}.cache.enabled" = true;
    "calendar.registry.${id}.refreshInterval" = refreshInterval;
    "calendar.registry.${id}.suppressAlarms" = false;
    "calendar.registry.${id}.calendar-main-in-composite" = true;
    "calendar.registry.${id}.calendar-main-default" = isDefault;
    "calendar.registry.${id}.imip.identity.disabled" = true;
    "calendar.registry.${id}.forceEmailScheduling" = false;
  };

  # Kalender-Definitionen
  calendarPrefs = mkCalendarPrefs {
    id = calId;
    name = "Kalender";
    uri = "${radicaleUrl}/${radicaleUser}/calendar.ics/";
    color = "#3366cc";
    isDefault = true;
  };

  contactsCalPrefs = mkCalendarPrefs {
    id = contactsId;
    name = "Geburtstage (Kontakte)";
    uri = "${radicaleUrl}/${radicaleUser}/contacts.vcf/";
    color = "#e67e22";
    calType = "caldav";
    refreshInterval = 60;
  };

  # Sortier-Reihenfolge: Alle Kalender-IDs kommasepariert
  calendarListOrder = "${calId} ${contactsId}";

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
        "christian@czichy.com" = {
          primary = true;
          realName = "Christian Czichy";
          address = "christian@czichy.com";
          imap = {
            host = "imap.ionos.de";
            port = 993;
            tls.enable = true;
          };
          smtp = {
            host = "smtp.ionos.de";
            port = 465;
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
            profiles = ["christian@czichy.com"];
          };
        };
      };
    }
    # |----------------------------------------------------------------------| #
    {
      programs.thunderbird = {
        enable = _ true;
        profiles."christian@czichy.com" = {
          isDefault = _ true;
          withExternalGnupg = true;

          settings =
            {
              # === General UI and behavior settings ===
              "layout.css.devPixelsPerPx" = "1";
              "intl.locale.requested" = "de-DE"; # UI language
              "spellchecker.dictionary" = "de-DE"; # Spellcheck language
              "intl.regional_prefs.use_os_locales" = true; # Don't use OS locale
              "intl.regional_prefs.locales" = "de-DE"; # Use metric etc.
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
            }
            # ---------------------------------------------------------------
            # CalDAV-Kalender deklarativ registrieren (Radicale)
            # ---------------------------------------------------------------
            // calendarPrefs
            // contactsCalPrefs
            // {
              "calendar.list.sortOrder" = calendarListOrder;
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

          "datareporting.healthreport.uploadEnabled" = false;
          "toolkit.telemetry.enabled" = false;
          "toolkit.telemetry.unified" = false;
          "toolkit.telemetry.archive.enabled" = false;
          "toolkit.telemetry.newProfilePing.enabled" = false;
          "toolkit.telemetry.shutdownPingSender.enabled" = false;
          "toolkit.telemetry.updatePing.enabled" = false;
          "toolkit.telemetry.bhrPing.enabled" = false;
          "toolkit.telemetry.firstShutdownPing.enabled" = false;
          "browser.ping-centre.telemetry" = false;

          "browser.search.defaultenginename" = "DuckDuckGo";
          "browser.search.selectedEngine" = "DuckDuckGo";

          "mail.biff.play_sound" = false;
          "mail.chat.play_sound" = false;

          # =============================================================
          # CalDAV / CardDAV – Radicale Integration (cal.czichy.com)
          # =============================================================
          # Kalender werden deklarativ über calendar.registry.* in den
          # Profil-Settings konfiguriert (siehe oben: calendarPrefs).
          #
          # Beim ersten Start fragt Thunderbird nach dem Passwort –
          # danach wird es im Thunderbird-Passwort-Manager gespeichert.
          #
          # CardDAV-Kontakte über CardBook (Add-on):
          #   CardBook → Neues Adressbuch → Remote → CardDAV
          #   URL: https://cal.czichy.com/christian/
          #   Benutzername: christian

          # Kalender-UI-Einstellungen
          "calendar.integration.notify" = true;
          "calendar.alarms.playsound" = false;
          "calendar.alarms.show" = true;
          "calendar.alarms.showmissed" = true;
          "calendar.network.multirealm" = true;

          # CalDAV-Debugging (bei Problemen auf true setzen)
          "calendar.debug.log" = false;
          "calendar.debug.log.verbose" = false;

          "thunderbird.policies.runOncePerModification.extensionsInstall" = "https://addons.thunderbird.net/thunderbird/downloads/latest/grammar-and-spell-checker/latest/latest.xpi,https://addons.thunderbird.net/thunderbird/downloads/latest/german-dictionary-de_de-for-sp/latest/latest.xpi,https://addons.thunderbird.net/thunderbird/downloads/latest/filelink-nextcloud-owncloud/latest/latest.xpi,https://addons.thunderbird.net/thunderbird/downloads/latest/cardbook/latest/latest.xpi";
        };
      };
    }
    # |----------------------------------------------------------------------| #
    (
      mkIf agenixCheck
      {
        age.secrets = {
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
        "x-scheme-handler/mailto" = ["thunderbird.desktop"];
        "x-scheme-handler/mid" = ["thunderbird.desktop"];
        "message/rfc822" = ["thunderbird.desktop"];
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
