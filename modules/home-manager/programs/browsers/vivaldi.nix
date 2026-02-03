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

  cfg = config.tensorfiles.hm.programs.browsers.vivaldi;
  _ = mkOverrideAtHmModuleLevel;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.hm.system.impermanence
    else {};
in {
  options.tensorfiles.hm.programs.browsers.vivaldi = with types; {
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
      programs.vivaldi = {
        enable = _ true;
        commandLineArgs = [
          "--disable-gpu-driver-bug-workarounds"
          "--enable-features=WaylandWindowDecorations"
          "--enable-gpu-rasterization"
          "--enable-zero-copy"
          "--ignore-gpu-blocklist"
          "--ozone-platform=wayland"
          "--ozone-platform-hint=auto"
          "--enable-features=WaylandWindowDecorations,CanvasOopRasterization,Vulkan,UseSkiaRenderer"
        ];
        extensions = [
          {id = "oboonakemofpalcgghocfoadofidjkkk";}
          {id = "clngdbkpkpeebahjckkjfobafhncgmne";}
        ];
      };
    }
    # |----------------------------------------------------------------------| #
    (mkIf impermanenceCheck {
      home.persistence."${impermanence.persistentRoot}" = {
        directories = [
          ".config/vivaldi"
          ".local/lib/vivaldi"
        ];
        files = [
          ".local/share/.vivaldi_reporting_data"
        ];
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
