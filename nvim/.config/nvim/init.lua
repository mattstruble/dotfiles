--------------------------
-- LAZY SETUP
--------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("globals")

local opts = {
  install = {
    colorscheme = { "catppuccin-mocha" },
  },
  ui = {
    border = "rounded",
  },
  checker = {
    enabled = true,
  },
}

require("lazy").setup({
  spec = {
    {
      "LazyVim/LazyVim",
      opts = {
        icons = {
          diagnostics = {
            Error = tools.ui.diagnostics.error_cod,
            Warn = tools.ui.diagnostics.warn_cod,
            Hint = tools.ui.diagnostics.hint_cod,
            Info = tools.ui.diagnostics.info_cod,
          },
        },
      },
    },
    { import = "lazyvim.plugins" },
    { import = "lazyvim.plugins.extras.dap.core" },
    { import = "lazyvim.plugins.extras.coding.blink" },
    { import = "lazyvim.plugins.extras.lang.docker" },
    { import = "lazyvim.plugins.extras.lang.terraform" },
    { import = "lazyvim.plugins.extras.lang.tex" },
    { import = "lazyvim.plugins.extras.lang.yaml" },
    { import = "lazyvim.plugins.extras.lang.json" },
    { import = "lazyvim.plugins.extras.lang.rust" },
    { import = "lazyvim.plugins.extras.lang.markdown" },
    { import = "lazyvim.plugins.extras.lang.ansible" },
    { import = "lazyvim.plugins.extras.lang.yaml" },
    { import = "lazyvim.plugins.extras.lang.nix" },
    { import = "lazyvim.plugins.extras.lang.toml" },
    { import = "plugins" },
    { import = "plugins.coding" },
    { import = "plugins.editor" },
    { import = "plugins.lang" },

    {
      "saghen/blink.cmp",
      dependencies = {
        { "saghen/blink.compat",      lazy = true, version = false },
        { "echasnovski/mini.snippets" },
      },
      opts = {
        snippets = { preset = 'mini_snippets' },
        completion = {
          trigger = {
            show_on_insert_on_trigger_character = false,
          },
        },
        sources = {
          default = { "lsp", "path", "snippets", "buffer" },
          compat = {
            "obsidian",
            "obsidian_new",
            "obsidian_tags",
          },
        },
      },
    },

    {
      "ibhagwan/fzf-lua",
      opts = {
        defaults = {
          hidden = true,
        },
        oldfiles = {
          cwd_only = true,
          stat_file = true, -- verify files exist on disk
          include_current_session = true,
        },
        previewers = {
          builtin = {
            syntax_limit_b = 1024 * 100,
          },
        },
      },
    },

    {
      "m4xshen/hardtime.nvim",
      dependencies = { "MunifTanjim/nui.nvim", "nvim-lua/plenary.nvim" },
      opts = {
        disabled_filetypes = {
          "qf",
          "netrw",
          "NvimTree",
          "lazy",
          "mason",
          "toggleterm",
          "neo-tree",
          "neo-tree-popup",
          "oil",
        },
        resetting_keys = {
          ["y"] = {},
          ["p"] = {},
          ["P"] = {},
        },
      },
    },

    {
      "actionshrimp/direnv.nvim",
      opts = {
        async = true,
        on_direnv_finished = function()
          -- You may also want to pair this with `autostart = false` in any `lspconfig` calls
          -- vim.cmd("LspStart")
          vim.cmd("LspRestart")
        end,
      },
    },

    -- LSP global configurations
    {
      "neovim/nvim-lspconfig",
      opts = {
        setup = {
          autostart = true,
        },
        diagnostics = {
          underline = false,
          update_in_insert = false,
          severity_sort = true,
          virtual_text = {
            severity = vim.diagnostic.severity.ERROR,
            spacing = 4,
            prefix = "",
          },
          float = {
            focusable = false,
            style = "minimal",
            border = "rounded",
            source = "always",
            header = "",
            prefix = "",
          },
        },
        inlay_hints = { enabled = true },
        autoformat = true,
        format_notify = false,
      },
    },

    {
      "nvim-neo-tree/neo-tree.nvim",
      lazy = false,
      ---@module "neo-tree"
      ---@type neotree.Config
      opts = {
        close_if_last_window = true,
        default_component_configs = {
          git_status = {
            symbols = {
              unstaged = "✗",
              staged = "✓",
              unmerged = "",
              renamed = "➜",
              untracked = "★",
              deleted = "",
              ignored = "◌",
            },
          },
        },
        window = {
          mappings = {
            ["a"] = {
              "add",
              config = {
                show_path = "relative",
              },
            },
          },
        },
        filesystem = {
          filtered_items = {
            hide_dotfiles = false,
            hide_by_pattern = {
              ".git",
            },
            always_show = {
              ".gitignore",
              ".github",
            },
            never_show = {
              ".DS_Store",
              "thumbs.db",
            },
            never_show_by_pattern = {
              ".null-ls_*",
            },
          },
          follow_current_file = {
            enabled = true,
          },
          hijack_netrw_behavior = "disabled",
          use_libuv_file_watcher = true,
        },
      },
    },

    {
      "zeioth/garbage-day.nvim",
      dependencies = "neovim/nvim-lspconfig",
      event = "VeryLazy",
    },

    {
      "nvim-pack/nvim-spectre",
      enabled = false,
    },

    {
      -- TODO: add key maps
      "nvim-neotest/neotest",
      dependencies = {
        "nvim-neotest/nvim-nio",
        "nvim-lua/plenary.nvim",
        "antoinemadec/FixCursorHold.nvim",
        "nvim-treesitter/nvim-treesitter",
      },
    },
  },
}, opts)

-- Show LSP diagnostics on hover using new neovim 0.11 virtual lines
-- https://gpanders.com/blog/whats-new-in-neovim-0-11/#virtual-lines
vim.diagnostic.config({
  virtual_text = false,
  virtual_lines = {
    current_line = true,
  },
  severity_sort = true,
  underline = true,
  signs = true,
  float = {
    focusable = false,
    style = "minimal",
    border = "rounded",
    source = true,
    header = "",
  }
})

-- Show LSP diagnostics (inlay hints) in a hover window / popup
-- https://github.com/neovim/nvim-lspconfig/wiki/UI-Customization#show-line-diagnostics-automatically-in-hover-window
-- https://www.reddit.com/r/neovim/comments/1168p97/how_can_i_make_lspconfig_wrap_around_these_hints/
-- Time it takes to show the popup after you hover over the line with an error
vim.o.updatetime = 400

-- LSP Folding
-- https://old.reddit.com/r/neovim/comments/1jmqd7t/sorry_ufo_these_7_lines_replaced_you/
vim.o.foldenable = true
vim.o.foldlevel = 99
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.o.foldtext = ""
