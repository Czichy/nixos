{pkgs, ...}: {
  programs.niri.settings = {
    binds."super+c".action.spawn = "${pkgs.qalculate-gtk}/bin/qalculate-gtk";
    window-rules = [
      {
        matches = [{app-id = "qalculate-gtk";}];
        open-floating = true;
      }
    ];
  };
}
