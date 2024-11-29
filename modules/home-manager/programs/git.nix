{localFlake}: {
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtHmModuleLevel;

  cfg = config.tensorfiles.hm.programs.git;
  _ = mkOverrideAtHmModuleLevel;
in {
  options.tensorfiles.hm.programs.git = with types; {
    enable = mkEnableOption ''
      TODO
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      home.packages = with pkgs; [
        gitoxide # An idiomatic, lean, fast & safe pure Rust implementation of Git
      ];
      programs.git = {
        enable = _ true;
        delta = {
          enable = _ true;
          options = {
            navigate = _ true;
            syntax-theme = _ "Nord";
          };
        };
        userName = mkIf (config.home.sessionVariables.DEFAULT_USERNAME != null) (
          _ config.home.sessionVariables.DEFAULT_USERNAME
        );
        userEmail = mkIf (config.home.sessionVariables.DEFAULT_MAIL != null) (
          _ config.home.sessionVariables.DEFAULT_MAIL
        );
        extraConfig = {
          github.user = mkIf (config.home.sessionVariables.DEFAULT_USERNAME != null) (
            _ config.home.sessionVariables.DEFAULT_USERNAME
          );
          init.defaultBranch = "develop";
        };
        aliases = {
          b = _ "branch";
          bl = _ "branch";
          bd = _ "branch -d";
          bdf = _ "branch -D";
          f = _ "fetch";
          fo = _ "fetch origin";
          c = _ "commit";
          ca = _ "commit -a";
          ch = _ "checkout";
          chb = _ "checkout -b";
          chr = _ "checkout --";
          chra = _ "checkout -- .";
          cl = _ "clone";
          ph = _ "push";
          phu = _ "push --set-upstream";
          phuo = _ "push --set-upstream origin";
          phuof = _ "push --set-upstream --force origin";
          phuf = _ "push --set-upstream --force";
          phf = _ "push --force";
          pl = _ "pull";
          plf = _ "pull --force";
          plo = _ "pull origin";
          plof = _ "pull origin --force";
          a = _ "add";
          aa = _ "add *";
          r = _ "reset HEAD";
          ra = _ "reset HEAD *";
          s = _ "status";
          sh = _ "stash";
          sha = _ "stash apply";
          rmc = _ "rm --cached";
          m = _ "merge";
          mf = _ "merge --force";
          i = _ "init";
          d = _ "diff";
          l = _ "log";
          lg1 = _ "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(auto)%d%C(reset)'";
          lg2 = _ "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(auto)%d%C(reset)%n''          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)'";
          lg3 = _ "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset) %C(bold cyan)(committed: %cD)%C(reset) %C(auto)%d%C(reset)%n''          %C(white)%s%C(reset)%n''          %C(dim white)- %an <%ae> %C(reset) %C(dim white)(committer: %cn <%ce>)%C(reset)'";
        };
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
