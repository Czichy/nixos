{localFlake}: {
  config,
  lib,
  pkgs,
  inputs,
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

  cfg = config.tensorfiles.hm.programs.browsers.zen-browser;
  _ = mkOverrideAtHmModuleLevel;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.hm.system.impermanence
    else {};
  pathToRelative = strings.removePrefix "${config.home.homeDirectory}/";
in {
  options.tensorfiles.hm.programs.browsers.zen-browser = with types; {
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
      programs.zen-browser = {
        enable = _ true;
        policies = {
          DisableTelemetry = true;
          DisableFirefoxStudies = true;
          EnableTrackingProtection = {
            Value = true;
            Locked = true;
            Cryptomining = true;
            Fingerprinting = true;
          };
          DisablePocket = true;
          DisableFirefoxAccounts = true;
          DisableAccounts = true;
          DisableFirefoxScreenshots = true;
          OverrideFirstRunPage = "";
          OverridePostUpdatePage = "";
          DontCheckDefaultBrowser = true;
          DisplayBookmarksToolbar = "never";
          DisplayMenuBar = "default-off";
          SearchBar = "unified";
          DefaultDownloadDirectory = "~/tmp";

          Preferences = {
            "browser.contentblocking.category" = "strict";
            "browser.disableResetPrompt" = true;
            "browser.download.panel.shown" = true;
            "browser.formfill.enable" = false;
            "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
            "browser.newtabpage.activity-stream.feeds.snippets" = false;
            "browser.newtabpage.activity-stream.feeds.telemetry" = false;
            "browser.newtabpage.activity-stream.section.highlights.includeBookmarks" = false;
            "browser.newtabpage.activity-stream.section.highlights.includeDownloads" = false;
            "browser.newtabpage.activity-stream.section.highlights.includePocket" = false;
            "browser.newtabpage.activity-stream.section.highlights.includeVisited" = false;
            "browser.newtabpage.activity-stream.showSponsored" = false;
            "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
            "browser.newtabpage.activity-stream.system.showSponsored" = false;
            "browser.newtabpage.activity-stream.telemetry" = false;
            "browser.ping-centre.telemetry" = false;
            "browser.search.suggest.enabled.private" = false;
            "browser.search.suggest.enabled" = false;
            "browser.shell.checkDefaultBrowser" = false;
            "browser.shell.defaultBrowserCheckCount" = 1;
            "browser.topsites.contile.enabled" = false;
            "browser.urlbar.showSearchSuggestionsFirst" = false;
            "browser.urlbar.suggest.searches" = false;
            "dom.security.https_only_mode" = true;
            "experiments.activeExperiment" = false;
            "experiments.enabled" = false;
            "experiments.supported" = false;
            "extensions.InstallTrigger.enabled" = false;
            "extensions.pocket.enabled" = false;
            "extensions.screenshots.disabled" = true;
            "full-screen-api.ignore-widgets" = true;
            "general.smoothScroll" = true;
            "identity.fxaccounts.enabled" = false;
            "media.ffmpeg.vaapi.enabled" = true;
            "media.rdd-vpx.enabled" = true;
            "network.allow-experiments" = false;
            "privacy.donottrackheader.enabled" = true;
            "privacy.partition.network_state.ocsp_cache" = true;
            "privacy.trackingprotection.enabled" = true;
            "privacy.trackingprotection.socialtracking.enabled" = true;
            "privacy.userContext.enabled" = false;
            "signon.rememberSignons" = false;
            "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
            "toolkit.telemetry.archive.enabled" = false;
            "toolkit.telemetry.bhrPing.enabled" = false;
            "toolkit.telemetry.enabled" = false;
            "toolkit.telemetry.firstShutdownPing.enabled" = false;
            "toolkit.telemetry.hybridContent.enabled" = false;
            "toolkit.telemetry.newProfilePing.enabled" = false;
            "toolkit.telemetry.reportingpolicy.firstRun" = false;
            "toolkit.telemetry.shutdownPingSender.enabled" = false;
            "toolkit.telemetry.unified" = false;
            "toolkit.telemetry.updatePing.enabled" = false;
            "widget.use-xdg-desktop-portal.file-picker" = true;
            "widget.use-xdg-desktop-portal.location" = true;
            "widget.use-xdg-desktop-portal.mime-handler" = true;
            "widget.use-xdg-desktop-portal.open-uri" = true;
            "widget.use-xdg-desktop-portal.settings" = true;
            "browser.uiCustomization.state" = builtins.toJSON {
              currentVersion = 20;
              dirtyAreaCache = [
                "unified-extensions-area"
                "nav-bar"
                "toolbar-menubar"
                "TabsToolbar"
                "PersonalToolbar"
              ];
              newElementCount = 4;
              placements = {
                PersonalToolbar = ["import-button" "personal-bookmarks"];
                TabsToolbar = ["tabbrowser-tabs" "new-tab-button" "alltabs-button"];
                nav-bar = [
                  "back-button"
                  "forward-button"
                  "stop-reload-button"
                  "urlbar-container"
                  "downloads-button"
                  "fxa-toolbar-menu-button"
                  "reset-pbm-toolbar-button"
                  "unified-extensions-button"
                ];
                toolbar-menubar = ["menubar-items"];
                unified-extensions-area = [
                  "addon_darkreader_org-browser-action"
                  "_a6c4a591-f1b2-4f03-b3ff-767e5bedf4e7_-browser-action"
                ];
                widget-overflow-fixed-list = [];
              };
              seen = [
                "addon_darkreader_org-browser-action"
                "_a6c4a591-f1b2-4f03-b3ff-767e5bedf4e7_-browser-action"
                "developer-button"
              ];
            };
          };
        };
        profiles.czichy = {
          id = 0;
          isDefault = true;
          bookmarks = {};
          extensions =
            # with addons;
            with inputs.firefox-addons.packages.${pkgs.system};
            # with pkgs.nur.repos.rycee.firefox-addons;
              [
                # Rycee NUR: https://nur.nix-community.org/repos/rycee/
                # dracula-dark-colorscheme
                bitwarden
                clearurls
                cookie-autodelete
                firefox-translations
                keepassxc-browser
                multi-account-containers
                rust-search-extension
                ublock-origin
                user-agent-string-switcher
              ];
          settings = let
            newTab = let
              activityStream = "browser.newtabpage.activity-stream";
            in {
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

        search = {
          force = true;
          default = "Google";
          engines = {
            "Nix Packages" = {
              urls = [
                {
                  template = "https://search.nixos.org/packages";
                  params = [
                    {
                      name = "type";
                      value = "packages";
                    }
                    {
                      name = "channel";
                      value = "unstable";
                    }
                    {
                      name = "query";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              definedAliases = ["@np"];
            };
            "Nix Options" = {
              urls = [
                {
                  template = "https://search.nixos.org/options";
                  params = [
                    {
                      name = "type";
                      value = "packages";
                    }
                    {
                      name = "channel";
                      value = "unstable";
                    }
                    {
                      name = "query";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              definedAliases = ["@no"];
            };
            "Home Manager" = {
              urls = [
                {
                  template = "https://home-manager-options.extranix.com/";
                  params = [
                    {
                      name = "query";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              definedAliases = ["@hm"];
            };
            "GitHub" = {
              urls = [
                {
                  template = "https://github.com/search";
                  params = [
                    {
                      name = "q";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              definedAliases = ["@gh"];
            };
            "GitLab" = {
              urls = [
                {
                  template = "https://gitlab.com/search";
                  params = [
                    {
                      name = "search";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              definedAliases = ["@gl"];
            };
            "YouTube" = {
              urls = [
                {
                  template = "https://www.youtube.com/results";
                  params = [
                    {
                      name = "search_query";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              definedAliases = ["@yt"];
            };
            "DuckDuckGo" = {
              urls = [
                {
                  template = "https://duckduckgo.com/";
                  params = [
                    {
                      name = "q";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              definedAliases = ["@dg"];
            };
            "Google" = {
              urls = [
                {
                  template = "https://www.google.com/search";
                  params = [
                    {
                      name = "q";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              definedAliases = ["@g"];
            };
            "Wikipedia" = {
              urls = [
                {
                  template = "https://en.wikipedia.org/w/index.php";
                  params = [
                    {
                      name = "search";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              definedAliases = ["@w"];
            };
            "Wikipedia (en)".metaData.hidden = true;
            "Amazon.com".metaData.hidden = true;
            "Bing".metaData.hidden = true;
            "eBay".metaData.hidden = true;
          };
        };
      };
    }
    # |----------------------------------------------------------------------| #
    (mkIf impermanenceCheck {
      home.persistence."${impermanence.persistentRoot}${config.home.homeDirectory}" = {
        directories = [
          ".zen/czichy"
          # (pathToRelative "${config.xdg.cacheHome}/.mozilla/firefox")
        ];
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
