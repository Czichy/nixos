# --- parts/modules/home-manager/programs/browsers/firefox.nix
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
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with builtins;
with lib;
let
  inherit (localFlake.lib.tensorfiles)
    mkOverrideAtHmModuleLevel
    isModuleLoadedAndEnabled
    mkImpermanenceEnableOption
    ;

  cfg = config.tensorfiles.hm.programs.browsers.firefox;
  _ = mkOverrideAtHmModuleLevel;

  plasmaCheck = isModuleLoadedAndEnabled config "tensorfiles.hm.profiles.graphical-plasma";

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.system.impermanence") && cfg.impermanence.enable;
  impermanence = if impermanenceCheck then config.tensorfiles.hm.system.impermanence else { };
  pathToRelative = strings.removePrefix "${config.home.homeDirectory}/";
in
{
  options.tensorfiles.hm.programs.browsers.firefox = with types; {
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
      programs.firefox = {
        enable = _ true;
        package = pkgs.firefox.override {
          # trace: warning: The cfg.enableTridactylNative argument for
          # `firefox.override` is deprecated, please add `pkgs.tridactyl-native`
          # to `nativeMessagingHosts.packages` instead
          nativeMessagingHosts = with pkgs; (optional plasmaCheck plasma-browser-integration);
          extraPolicies = {
            CaptivePortal = false;
            DisableFirefoxStudies = true;
            DisablePocket = true;
            DisableTelemetry = true;
            DisableFirefoxAccounts = false;
            # NoDefaultBookmarks = true;
            OfferToSaveLogins = false;
            OfferToSaveLoginsDefault = false;
            PasswordManagerEnabled = false;
            FirefoxHome = {
              Search = true;
              Pocket = false;
              Snippets = false;
              TopSites = false;
              Highlights = false;
            };
            UserMessaging = {
              ExtensionRecommendations = false;
              SkipOnboarding = true;
            };
            "3rdparty".Extensions = {
              "uBlock0@raymondhill.net" = {
                # uBlock settings are written in JSON to be more compatible with the
                # backup format. This checks the syntax.
                adminSettings = builtins.fromJSON (builtins.readFile ./ublock-settings.json);
              };
            };
          };
        };
        profiles.czichy = {
          id = 0;
          isDefault = true;
          bookmarks = { };
          extensions =
            # with addons;
            with inputs.firefox-addons.packages.${pkgs.system};
            # with pkgs.nur.repos.rycee.firefox-addons;
            [
              # Rycee NUR: https://nur.nix-community.org/repos/rycee/
              user-agent-string-switcher
              rust-search-extension
              ublock-origin
              multi-account-containers
              clearurls
              cookie-autodelete
              firefox-translations
              keepassxc-browser
              # dracula-dark-colorscheme
            ];
          settings =
            let
              newTab =
                let
                  activityStream = "browser.newtabpage.activity-stream";
                in
                {
                  "${activityStream}.feeds.topsites" = true;
                  "${activityStream}.feeds.section.highlights" = true;
                  "${activityStream}.feeds.section.topstories" = false;
                  "${activityStream}.feeds.section.highlights.includePocket" = false;
                  "${activityStream}.section.highlights.includePocket" = false;
                  "${activityStream}.showSearch" = false;
                  "${activityStream}.showSponsoredTopSites" = false;
                  "${activityStream}.showSponsored" = false;
                };

              searchBar = {
                "browser.urlbar.suggest.quicksuggest.sponsored" = false;
                "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
                "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShorcuts" = false;
                "browser.urlbar.showSearchSuggestionsFirst" = false;
              };

              extensions = {
                "extensions.update.autoUpdateDefault" = false;
                "extensions.update.enabled" = false;
              };

              telemetry = {
                "browser.newtabpage.activity-stream.telemetry" = false;
                "browser.newtabpage.activity-stream.feeds.telemetry" = false;
                "browser.ping-centre.telemetry" = false;
                "toolkit.telemetry.reportingpolicy.firstRun" = false;
                "toolkit.telemetry.unified" = false;
                "toolkit.telemetry.archive.enabled" = false;
                "toolkit.telemetry.updatePing.enabled" = false;
                "toolkit.telemetry.shutdownPingSender.enabled" = false;
                "toolkit.telemetry.newProfilePing.enabled" = false;
                "toolkit.telemetry.bhrPing.enabled" = false;
                "toolkit.telemetry.firstShutdownPing.enabled" = false;
                "datareporting.healthreport.uploadEnabled" = false;
                "datareporting.policy.dataSubmissionEnabled" = false;
                "security.protectionspopup.recordEventTelemetry" = false;
                "security.identitypopup.recordEventTelemetry" = false;
                "security.certerrors.recordEventTelemetry" = false;
                "security.app_menu.recordEventTelemetry" = false;
                "toolkit.telemetry.pioneer-new-studies-available" = false;
                "app.shield.optoutstudies.enable" = false;
              };

              privacy = {
                # clipboard events: https://superuser.com/questions/1595994/dont-let-websites-overwrite-clipboard-in-firefox-without-explicitly-giving-perm
                # Breaks copy/paste on websites
                #"dom.event.clipboardevents.enabled" = false;
                "dom.battery.enabled" = false;
                # "privacy.resistFingerprinting" = true;
              };

              https = {
                "dom.security.https_only_mode" = false;
                "dom.security.https_only_mode_ever_enabled" = false;
              };

              graphics = {
                # TODO
                #"media.ffmpeg.vaapi.enabled" = true;
                "media.gpu-process-decoder" = true;
                "dom.webgpu.enabled" = true;
                "gfx.webrender.all" = true;
                "layers.mlgpu.enabled" = true;
                "layers.gpu-process.enabled" = true;
              };

              generalSettings = {
                "widget.use-xdg-desktop-portal.file-picker" = 2;
                "widget.use-xdg-desktop-portal.mime-handler" = 2;
                "browser.aboutConfig.showWarning" = false;
                "browser.tabs.warnOnClose" = true;
                "browser.tabs.warnOnCloseOtherTabs" = true;
                "browser.warnOnQuit" = true;
                "browser.shell.checkDefaultBrowser" = false;
                "browser.urlbar.showSearchSuggestionsFirst" = false;
                "extensions.htmlaboutaddons.inline-options.enabled" = false;
                "extensions.htmlaboutaddons.recommendations.enabled" = false;
                "extensions.pocket.enabled" = false;
                "browser.fullscreen.autohide" = false;
                "browser.contentblocking.category" = "standard";
                # "browser.display.use_document_fonts" = 0; Using enable-browser-fonts extension instead
              };

              toolbars = {
                "browser.tabs.firefox-view" = false;
                "browser.toolbars.bookmarks.visibility" = "newtab";
              };

              passwords = {
                "signon.rememberSignons" = false;
                "signon.autofillForms" = false;
                "signon.generation.enabled" = false;
                "signon.management.page.breach-alerts.enabled" = false;
              };

              downloads = {
                "browser.download.useDownloadDir" = false;
                "browser.download.autohideButton" = false;
                "browser.download.always_ask_before_handling_new_types" = true;
              };
            in
            generalSettings
            // passwords
            // extensions
            // https
            // newTab
            // searchBar
            // privacy
            // telemetry
            // graphics
            // downloads
            // toolbars;
        };
        profiles.tradingview1 = {
          id = 1;
          isDefault = false;
          bookmarks = { };
          extensions =
            # with addons;
            with inputs.firefox-addons.packages.${pkgs.system};
            #  with pkgs.nur.repos.rycee.firefox-addons;
            [
              # Rycee NUR: https://nur.nix-community.org/repos/rycee/
              user-agent-string-switcher
              rust-search-extension
              ublock-origin
              multi-account-containers
              clearurls
              cookie-autodelete
              firefox-translations
              keepassxc-browser
              # dracula-dark-colorscheme
            ];
          settings =
            let
              newTab =
                let
                  activityStream = "browser.newtabpage.activity-stream";
                in
                {
                  "${activityStream}.feeds.topsites" = true;
                  "${activityStream}.feeds.section.highlights" = true;
                  "${activityStream}.feeds.section.topstories" = false;
                  "${activityStream}.feeds.section.highlights.includePocket" = false;
                  "${activityStream}.section.highlights.includePocket" = false;
                  "${activityStream}.showSearch" = false;
                  "${activityStream}.showSponsoredTopSites" = false;
                  "${activityStream}.showSponsored" = false;
                };

              searchBar = {
                "browser.urlbar.suggest.quicksuggest.sponsored" = false;
                "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
                "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShorcuts" = false;
                "browser.urlbar.showSearchSuggestionsFirst" = false;
              };

              extensions = {
                "extensions.update.autoUpdateDefault" = false;
                "extensions.update.enabled" = false;
              };

              telemetry = {
                "browser.newtabpage.activity-stream.telemetry" = false;
                "browser.newtabpage.activity-stream.feeds.telemetry" = false;
                "browser.ping-centre.telemetry" = false;
                "toolkit.telemetry.reportingpolicy.firstRun" = false;
                "toolkit.telemetry.unified" = false;
                "toolkit.telemetry.archive.enabled" = false;
                "toolkit.telemetry.updatePing.enabled" = false;
                "toolkit.telemetry.shutdownPingSender.enabled" = false;
                "toolkit.telemetry.newProfilePing.enabled" = false;
                "toolkit.telemetry.bhrPing.enabled" = false;
                "toolkit.telemetry.firstShutdownPing.enabled" = false;
                "datareporting.healthreport.uploadEnabled" = false;
                "datareporting.policy.dataSubmissionEnabled" = false;
                "security.protectionspopup.recordEventTelemetry" = false;
                "security.identitypopup.recordEventTelemetry" = false;
                "security.certerrors.recordEventTelemetry" = false;
                "security.app_menu.recordEventTelemetry" = false;
                "toolkit.telemetry.pioneer-new-studies-available" = false;
                "app.shield.optoutstudies.enable" = false;
              };

              privacy = {
                # clipboard events: https://superuser.com/questions/1595994/dont-let-websites-overwrite-clipboard-in-firefox-without-explicitly-giving-perm
                # Breaks copy/paste on websites
                #"dom.event.clipboardevents.enabled" = false;
                "dom.battery.enabled" = false;
                # "privacy.resistFingerprinting" = true;
              };

              https = {
                "dom.security.https_only_mode" = false;
                "dom.security.https_only_mode_ever_enabled" = false;
              };

              graphics = {
                # TODO
                #"media.ffmpeg.vaapi.enabled" = true;
                "media.gpu-process-decoder" = true;
                "dom.webgpu.enabled" = true;
                "gfx.webrender.all" = true;
                "layers.mlgpu.enabled" = true;
                "layers.gpu-process.enabled" = true;
              };

              generalSettings = {
                "widget.use-xdg-desktop-portal.file-picker" = 2;
                "widget.use-xdg-desktop-portal.mime-handler" = 2;
                "browser.aboutConfig.showWarning" = false;
                "browser.tabs.warnOnClose" = true;
                "browser.tabs.warnOnCloseOtherTabs" = true;
                "browser.warnOnQuit" = true;
                "browser.shell.checkDefaultBrowser" = false;
                "browser.urlbar.showSearchSuggestionsFirst" = false;
                "extensions.htmlaboutaddons.inline-options.enabled" = false;
                "extensions.htmlaboutaddons.recommendations.enabled" = false;
                "extensions.pocket.enabled" = false;
                "browser.fullscreen.autohide" = false;
                "browser.contentblocking.category" = "standard";
                # "browser.display.use_document_fonts" = 0; Using enable-browser-fonts extension instead
              };

              toolbars = {
                "browser.tabs.firefox-view" = false;
                "browser.toolbars.bookmarks.visibility" = "newtab";
              };

              passwords = {
                "signon.rememberSignons" = false;
                "signon.autofillForms" = false;
                "signon.generation.enabled" = false;
                "signon.management.page.breach-alerts.enabled" = false;
              };

              downloads = {
                "browser.download.useDownloadDir" = false;
                "browser.download.autohideButton" = false;
                "browser.download.always_ask_before_handling_new_types" = true;
              };
            in
            generalSettings
            // passwords
            // extensions
            // https
            // newTab
            // searchBar
            // privacy
            // telemetry
            // graphics
            // downloads
            // toolbars;
        };
      };
    }
    # |----------------------------------------------------------------------| #
    (mkIf impermanenceCheck {
      home.persistence."${impermanence.persistentRoot}${config.home.homeDirectory}" = {
        directories = [
          ".mozilla/firefox"
          (pathToRelative "${config.xdg.cacheHome}/.mozilla/firefox")
        ];
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.tensorfiles.maintainers; [ czichy ];
}
