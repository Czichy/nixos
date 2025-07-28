{
  pkgs,
  config,
  ...
} @ inputs: let
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

    # --- Ui/ux Preferences ---
    "general.smoothScroll" = false;
    "mousewheel.default.delta_multiplier_y" = 50;
    "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

    # --- Zen Specific ---
    "zen.sidebar.enabled" = true;
    "zen.themes.updated-value-observer" = true;
    "zen.urlbar.behavior" = "floating-on-type";
    "zen.view.experimental-rounded-view" = true;
    "zen.welcome-screen.seen" = true;
    "zen.workspaces.container-specific-essentials-enabled" = true;
    "zen.workspaces.show-workspace-indicator" = false;

    # --- Download Settings ---
    "browser.download.lastDir" = "${config.home.homeDirectory}/Downloads";
  };
in {
  # shortcuts
  # appearance
  programs.zen-browser.profiles.czichy = {
    isDefault = true;
    settings = zenProfileSettings;
    search = import ./search.nix inputs;
    extensions = import ./extensions.nix inputs;
  };
  home.file.".zen/default-profile/zen-keyboard-shortcuts.json".source = ./shortcuts.json;
}
