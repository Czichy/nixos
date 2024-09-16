{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
in {
  config.modules.system.programs = mkIf config.modules.profiles.workstation.enable {
    webcord.enable = false;
    element.enable = false;
    libreoffice.enable = true;
    firefox.enable = true;
    thunderbird.enable = false;
    zathura.enable = true;
  };
}
