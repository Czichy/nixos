{pkgs}: let
  flavour = "storm";
in {
  add_newline = false;
  character = {
    success_symbol = "[](bold green)";
    error_symbol = "[](red) ";
    vicmd_symbol = "[](light-green)";
    # format = "$symbol[ ](bold base5 ";
    # format = "$symbol[λ ](bold base5) ";
    format = "$symbol[❯](bold blue) ";
  };
  format = "$directory$git_branch$git_commit\n$character";
  palette = "tokyo-night-${flavour}";
  palettes = {
    tokyo-night-storm = {
      blue = "#0DB9D7";
      red = "#F7768E";
      green = "#9ECE6A";
      purple = "#BB9AF7";
      base = "#24283B";
      base1 = "#16161E";
      base2 = "#343A52";
      base4 = "#787C99";
      base5 = "#A9B1D6";
      text = "#CBCCD1";
      text1 = "#D5D6DB";
      grey = "#C0CAF5";
      seaweed = "#B4F9F8";
      cyan = "#2AC3DE";
    };
  };
  right_format = "$all";
  command_timeout = 2000;
  scan_timeout = 100;
  git_branch = {
    format = "on [$symbol$branch(:$remote_branch)]($style) ";
    symbol = " ";
    style = "bold purple";
  };
  git_commit = {
    format = "[\($hash$tag\)]($style) ";
    commit_hash_length = 7;
    style = "bold green";
  };
  golang = {
    format = "via [$symbol($version )]($style)";
    style = "bold blue";
    symbol = "[ ]($style)";
  };
  lua = {
    format = "via [$symbol($version )]($style)";
    symbol = "[]($style) ";
    style = "bold blue";
  };
  nix_shell = {
    symbol = " ";
    format = "via [$symbol$state]($style) ";
    # symbol = "󱄅 ";
    # format = "via [$symbol$state( \($name\))]($style) ";
    style = "bold blue";
    disabled = false;
  };
  nodejs = {
    format = "via [$symbol($version )]($style)";
    style = "bold green";
    symbol = " ";
    version_format = "v$raw(blue)";
  };
  ocaml = {
    format = "via [$symbol($version )(\($switch_indicator$switch_name\) )]($style)";
    symbol = "🐫 ";
    style = "bold yellow";
    version_format = "v$raw";
  };
  package = {
    format = "is [$symbol$version]($style) ";
    symbol = " ";
    style = "bold 208";
  };
  python = {
    format = "via [$symbol$pyenv_prefix($version )(\($virtualenv\) )]($style)";
    symbol = "[]($style) ";
    style = "bold yellow";
  };

  rust = {
    format = "via [$symbol($version )]($style)";
    symbol = "[]($style) ";
    style = "bold red";
  };
  zig = {
    format = "via [$symbol($version )]($style)";
    symbol = "[ ]($style)";
    style = "bold yellow";
  };
  username = {
    show_always = false;
    format = "[ $user]($style) ";
    style_user = "bold bg:none fg:cyan";
  };
  directory = {
    read_only = " 󰌾";
    truncation_length = 3;
    truncation_symbol = "./";
    style = "bold bg:none fg:grey";
  };
  time = {
    use_12hr = false;
    time_range = "-";
    time_format = "%T";
    utc_time_offset = "local";
    format = "[ $time 󰥔]($style) ";
    style = "bold base3";
  };
  c = {
    symbol = " ";
  };
  nim = {
    symbol = "󰆥 ";
  };
  julia.symbol = " ";
  php.symbol = " ";
  ruby.symbol = " ";
}
# // builtins.fromTOML (
#   builtins.readFile (
#     pkgs.fetchFromGitHub {
#       owner = "catppuccin";
#       repo = "starship";
#       rev = "HEAD";
#       sha256 = "sha256-t/Hmd2dzBn0AbLUlbL8CBt19/we8spY5nMP0Z+VPMXA=";
#     }
#     + /themes/${flavour}.toml
#   )
# )

