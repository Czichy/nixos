{
  pkgs,
  config,
  ...
} @ inputs: let
  zen-nebula = pkgs.fetchFromGitHub {
    owner = "JustAdumbPrsn";
    repo = "Zen-Nebula";
    rev = "2077acd9102b98d9bfc79387dc6030af328826e4";
    sha256 = "sha256-Eg9HsN+yDA8OdVcE9clS+FyUhVBH3ooN/odkZIVR/p4=";
  };

  zenProfileSettings = {
    # --- Core Functionality ---
    "browser.aboutConfig.showWarning" = false;
    "browser.shell.checkDefaultBrowser" = false;
    "browser.shell.didSkipDefaultBrowserCheckOnFirstRun" = true;
    "browser.startup.page" = 3; # Resume last session.
    "browser.tabs.closeWindowWithLastTab" = false;
    "browser.tabs.warnOnOpen" = false;

    # --- UI ---
    "ui.textScaleFactor" = 150;
    "layout.css.devPixelsPerPx" = "1.25";
    "browser.zoom.full" = true;
    "zoom.defaultZoom" = 125;

    # --- Language ---
    "intl.accept_languages" = "de-DE, de, en-US, en";
    "intl.locale.requested" = "de";
    "general.useragent.locale" = "de";

    # --- Zen Pins ---
    "zen.pinned-tab-manager.close-on-unpin" = false;
    "zen.pinned-tab-manager.show-favicon-only" = true;
    "zen.pinned-tab-manager.compact-view" = true;

    # --- Privacy Settings ---
    "dom.security.https_only_mode" = true;
    "dom.security.https_only_mode_ever_enabled" = true;
    "privacy.donottrackheader.enabled" = true;
    "privacy.globalprivacycontrol.was_ever_enabled" = true;
    "network.dns.disablePrefetch" = true;
    "network.http.speculative-parallel-limit" = 0;
    "network.predictor.enabled" = false;
    "network.prefetch-next" = false;

    # --- Telemetry/tracking Disable ---
    "app.shield.optoutstudies.enabled" = false;
    "datareporting.policy.dataSubmissionPolicyAcceptedVersion" = 2;
    "toolkit.telemetry.reportingpolicy.firstRun" = false;

    # --- Appearance ---
    "ui.systemUsesDarkTheme" = 1;
    "browser.theme.dark-private-windows" = true;
    "browser.theme.content-theme" = 0;

    # --- Ui/ux Preferences ---
    "general.smoothScroll" = false;
    "mousewheel.default.delta_multiplier_y" = 50;
    "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

    # --- Nebula Theme ---
    "browser.tabs.allow_transparent_browser" = true;

    # --- Zen Specific ---
    "zen.sidebar.enabled" = true;
    "zen.themes.updated-value-observer" = true;
    "zen.urlbar.behavior" = "always-floating";
    "zen.view.experimental-rounded-view" = true;
    "zen.welcome-screen.seen" = true;
    "zen.workspaces.container-specific-essentials-enabled" = true;
    "zen.workspaces.show-workspace-indicator" = false;

    # --- Download Settings ---
    "browser.download.lastDir" = "${config.home.homeDirectory}/Downloads";

    # --- File Picker ---
    "widget.use-xdg-desktop-portal.file-picker" = true;
    "widget.use-xdg-desktop-portal.location" = true;
    "widget.use-xdg-desktop-portal.mime-handler" = true;
    "widget.use-xdg-desktop-portal.open-uri" = true;
    "widget.use-xdg-desktop-portal.settings" = true;
  };
in {
  programs.zen-browser.profiles.czichy = {
    isDefault = true;
    settings = zenProfileSettings;
    search = import ./search.nix inputs;
    extensions = import ./extensions.nix inputs;

    # --- Containers (one per space for identity isolation) ---
    containersForce = true;
    containers = import ./containers.nix inputs;

    # --- Spaces ---
    # Note: close Zen Browser before rebuilding to avoid session conflicts.
    spacesForce = true;
    spaces =
      (import ./spaces/default-space.nix inputs)
      // (import ./spaces/smart-home.nix inputs)
      // (import ./spaces/trading.nix inputs)
      // (import ./spaces/dev.nix inputs);

    # --- Pinned Tabs ---
    pinsForce = true;
    pins = import ./pins/smart-home-pins.nix inputs;
  };
  home.file.".config/zen/default-profile/zen-keyboard-shortcuts.json".source = ./shortcuts.json;

  # --- Nebula Theme (via userChrome.css) ---
  home.file.".config/zen/czichy/chrome/userChrome.css".source = "${zen-nebula}/userChrome.css";
  home.file.".config/zen/czichy/chrome/userContent.css".source = "${zen-nebula}/userContent.css";
  home.file.".config/zen/czichy/chrome/Nebula".source = "${zen-nebula}/Nebula";
}
