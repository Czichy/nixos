{
  localFlake,
  inputs,
}: {
  config,
  lib,
  pkgs,
  system,
  ...
}:
with builtins;
with lib; let
  inherit
    (localFlake.lib)
    mkOverrideAtHmModuleLevel
    isModuleLoadedAndEnabled
    mkPywalEnableOption
    mkDummyDerivation
    ;

  cfg = config.tensorfiles.hm.programs.editors.neovim;
  _ = mkOverrideAtHmModuleLevel;

  pywalCheck = (isModuleLoadedAndEnabled config "tensorfiles.hm.programs.pywal") && cfg.pywal.enable;
in {
  # TODO modularize config, cant be bothered to do it now
  options.tensorfiles.hm.programs.editors.neovim = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the neovim program.
    '';

    pywal = {
      enable = mkPywalEnableOption;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      home.shellAliases = {
        "neovim" = _ "nvim";
      };
      programs.neovim = {
        enable = _ true;
        viAlias = _ true;
        vimAlias = _ true;
        # error: The option `programs.neovim.withPython' can no longer be used
        # since it's been removed. Python2 support has been removed from neovim
        # withPython3 = _ true;
        withNodeJs = _ true;
        extraConfig = ''
          set number
          set relativenumber

          set formatoptions+=l
          set rulerformat=%l:%c
          set nofoldenable

          set wildmenu
          set wildmode=full
          set wildignorecase
          set clipboard+=unnamedplus

          set tabstop=8
          set softtabstop=0
          set expandtab
          set shiftwidth=4
          set smarttab

          set scrolloff=5

          set list
          set listchars=tab:»·,trail:•,extends:#,nbsp:.

          filetype indent on
          set smartindent
          set shiftround

          set ignorecase
          set smartcase
          set showmatch

          autocmd BufWritePre * :%s/\\s\\+$//e

          let mapleader="\<Space>"
          let maplocalleader="\<space>"

          ino jk <esc>
          ino kj <esc>
          cno jk <c-c>
          cno kj <c-c>
          tno jk <c-\><c-n>
          tno kj <c-\><c-n>
          vno jk <esc>
          vno kj <esc>

          nnoremap J :tabprevious<CR>
          nnoremap K :tabnext<CR>
        '';
        plugins = with pkgs.vimPlugins; (
          [
            {
              plugin = mkDummyDerivation "vscode-neovim-setup" system {};
              # type = "lua";
              config = ''
                if exists('g:vscode')
                  set noloadplugins
                  set clipboard^=unnamed,unnamedplus

                  finish
                endif
              '';
            }
          ]
          ++ (optional pywalCheck {
            plugin = pywal-nvim;
            type = "lua";
            config = ''
              require('pywal').setup()
            '';
          })
          ++ [
            vim-repeat
            # nnn-vim
            vim-fugitive
            popup-nvim
            plenary-nvim
            nvim-web-devicons
            bufexplorer
            undotree
            lexima-vim
            vim-vsnip-integ
            friendly-snippets
            {
              plugin = indentLine;
              type = "lua";
              config = ''
                vim.g.indentLine_char = '┆'
                vim.g.indentLine_color_term = 239
              '';
            }
            {
              plugin = vim-vsnip;
              type = "lua";
              config = "";
            }
            {
              plugin = vim-move;
              type = "lua";
              config = ''
                vim.g.move_key_modifier = "C"
              '';
            }
            {
              plugin = vim-suda;
              type = "lua";
              config = ''
                vim.g.move_key_modifier = "C"
              '';
            }
            {
              plugin = telescope-nvim;
              type = "lua";
              config = ''
                require('telescope').setup{
                  defaults = {
                    prompt_prefix = "🔍"
                  }
                }
              '';
            }
            {
              plugin = quick-scope;
              type = "lua";
              config = '''';
            }
            {
              plugin = hop-nvim;
              type = "lua";
              config = ''
                require('hop').setup{ keys = 'asdfghjkl' }

                vim.keymap.set("n", ",", "<cmd>HopChar2<CR>", {})
              '';
            }
            # {
            #   plugin = vim-easymotion;
            #   type = "lua";
            #   config = ''
            #     vim.g.EasyMotion_do_mapping = false
            #     vim.g.EasyMotion_smartcase = true

            #     vim.keymap.set("n", ",", "<Plug>(easymotion-overwin-f2)", {})
            #   '';
            # }
            {
              plugin = lualine-nvim;
              type = "lua";
              config = ''
                require('lualine').setup{
                  options = {
                    ${
                  if pywalCheck
                  then "theme = 'pywal-nvim',"
                  else ""
                }
                    icons_enabled = true
                  },
                  sections = {
                    lualine_a = {{"mode", upper=true}},
                    lualine_b = {{"branch", icon=""}},
                    lualine_c = {{"filename", file_status=true}},
                    lualine_x = {"encoding", "fileformat", "filetype"},
                    lualine_y = {"progress"},
                    lualine_z = {"location"},
                  }
                }
              '';
            }
            # {
            #   plugin = nvim-treesitter.withAllGrammars;
            #   type = "lua";
            #   config = ''
            #     require('nvim-treesitter.configs').setup{
            #       sync_install = false,
            #       auto_install = false,
            #       highlight = {
            #         enable = true,
            #         disable = { "latex" }
            #       },
            #       incremental_selection = {
            #         enable = true
            #       },
            #       indent = {
            #         enable = true
            #       }
            #     };
            #   '';
            # }
            # {
            #   plugin = fern-vim;
            #   type = "lua";
            #   config = ''
            #     vim.g.loaded_netrw = false
            #     vim.g.loaded_netrwPlugin = false
            #     vim.g.loaded_netrwSettings = false
            #     vim.g.loaded_netrwFileHandlers = false

            #     -- vim.g["fern#renderer"] = "nerdfont" TODO
            #     vim.g["fern#disable_default_mappings"] = true

            #     vim.api.nvim_set_keymap(
            #       "n",
            #       "m",
            #       ":Fern . -drawer -reveal=% -width=35 <CR><C-w>=",
            #       {noremap=true, silent=true}
            #     )

            #     vim.api.nvim_set_keymap(
            #       "n",
            #       "<Plug>(fern-close-drawer)",
            #       ":<C-u>FernDo close -drawer -stay<CR>",
            #       {noremap=true, silent=true}
            #     )

            #     local function fern_init()
            #       local opts = {silent=true}
            #       vim.api.nvim_set_keymap("n", "<Plug>(fern-action-open)",
            #         "<Plug>(fern-action-open:select)", opts)

            #       vim.api.nvim_buf_set_keymap(
            #         0,
            #         "n",
            #         "<Plug>(fern-action-custom-open-expand-collapse)",
            #         "fern#smart#leaf('<plug>(fern-action-open)<plug>(fern-close-drawer)', '<plug>(fern-action-expand)', '<plug>(fern-action-collapse)')",
            #         {silent=true, expr=true}
            #       )
            #       vim.api.nvim_buf_set_keymap(0, "n", "q", ":<C-u>quit<CR>", opts)
            #       vim.api.nvim_buf_set_keymap(0, "n", "n", "<Plug>(fern-action-new-path)", opts)
            #       vim.api.nvim_buf_set_keymap(0, "n", "d", "<Plug>(fern-action-remove)", opts)
            #       vim.api.nvim_buf_set_keymap(0, "n", "m", "<Plug>(fern-action-move)", opts)
            #       vim.api.nvim_buf_set_keymap(0, "n", "r", "<Plug>(fern-action-rename)", opts)
            #       vim.api.nvim_buf_set_keymap(0, "n", "R", "<Plug>(fern-action-reload)", opts)
            #       vim.api.nvim_buf_set_keymap(0, "n", "<C-h>", "<Plug>(fern-action-hidden-toggle)", opts)
            #       vim.api.nvim_buf_set_keymap(0, "n", "l", "<Plug>(fern-action-custom-open-expand-collapse)", opts)
            #       vim.api.nvim_buf_set_keymap(0, "n", "h", "<Plug>(fern-action-collapse)", opts)
            #       vim.api.nvim_buf_set_keymap(0, "n", "<2-LeftMouse>", "<Plug>(fern-action-custom-open-expand-collapse)", opts)
            #       vim.api.nvim_buf_set_keymap(0, "n", "<CR>", "<Plug>(fern-action-custom-open-expand-collapse)", opts)
            #     end

            #     local group = vim.api.nvim_create_augroup("fern_group", {clear=true})
            #     vim.api.nvim_create_autocmd("FileType", {
            #       pattern="fern",
            #       callback=fern_init,
            #       group=group
            #     })
            #   '';
            # }
            {
              plugin = which-key-nvim;
              type = "lua";
              config = ''
                vim.api.nvim_set_option("timeoutlen", 500)

                require('which-key').register({
                  {
                    name = "+general",
                    ["<leader>"] = { ":Telescope find_files<CR>", "find-files" },
                    ["/"] = { ":Telescope live_grep<CR>", "telescope-grep" },
                    r = { ":noh<CR>", "highlights-remove" },
                    h = { "<C-w>h", "window-left" },
                    j = { "<C-w>j", "window-below" },
                    k = { "<C-w>k", "window-above" },
                    l = { "<C-w>l", "window-right" },
                    s = { "<C-w>s", "window-split-below" },
                    v = { "<C-w>v", "window-split-right" },
                    q = { ":q<CR>", "file-quit" },
                    Q = { ":qall<CR>", "file-quit-all" },
                    w = { ":w<CR>", "file-save" },
                    n = { ":tabnew<CR>", "tab-new" },
                    u = { ":UndotreeToggle<CR>", "undotree-toggle" },
                    t = { ":terminal<CR>", "terminal-open" },
                    --- f = { ":NnnPicker %:p:h<CR>", "nnn-open" }
                  },
                  g = {
                    name = "+git",
                    s = { ":Git<CR>", "git-status" },
                    b = { ":Git blame<CR>", "git-blame" },
                    d = { ":Gdiff<CR>", "git-diff" },
                    p = { ":Git push<CR>", "git-push" },
                    l = { ":Git pull<CR>", "git-pull" },
                    f = { ":Git fetch<CR>", "git-pull" },
                    a = { ":Git add *<CR>", "git-add-all" },
                    c = { ":Git commit --verbose<CR>", "git-commit-verbose" },
                    e = { ":GitMessenger<CR>", "git-messenger" }
                  },
                  p = {
                    name = "+telescope",
                    f = { ":Telescope find_files<CR>", "telescope-files" },
                    g = { ":GFiles<CR>", "telescope-git-files" },
                    b = { ":Telescope buffers<CR>", "telescope-buffers" },
                    l = { ":Colors<CR>", "telescope-colors" },
                    r = { ":Telescope live_grep<CR>", "telescope-grep" },
                    g = { ":Telescope git_commits<CR>", "telescope-commits" },
                    s = { ":Snippets<CR>", "telescope-snippets" },
                    m = { ":Telescope commands<CR>", "telescope-commands" },
                    h = { ":Telescope man_pages<CR>", "telescope-man-pages" },
                    -- t = { ":Telescope treesitter<CR>", "telescope-treesitter" }
                  },
                  b = {
                    name = "+bufexplorer",
                    i = "bufexplorer-open",
                    t = "bufexplorer-toggle",
                    s = "bufexplorer-horizontal-split",
                    v = "bufexplorer-vertical-split"
                  }
                }, { prefix = "<leader>" })
              '';
            }
            (pkgs.vimUtils.buildVimPlugin {
              pname = "kitty-scrollback.nvim";
              version = inputs.kitty-scrollback-nvim.rev;
              src = inputs.kitty-scrollback-nvim;
            })
          ]
        );
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
