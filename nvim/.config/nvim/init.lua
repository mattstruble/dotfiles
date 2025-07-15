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
        colorscheme = { "bamboo" },
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
                { "echasnovski/mini.snippets" },
            },
            opts = {
                snippets = { preset = "mini_snippets" },
                completion = {
                    trigger = {
                        show_on_insert_on_trigger_character = false,
                    },
                },
                sources = {
                    default = { "lsp", "path", "snippets", "buffer" },
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
                    "snacks_terminal",
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
            dependencies = {
                "williamboman/mason.nvim",
                "williamboman/mason-lspconfig.nvim",
                "saghen/blink.cmp",
            },
            opts = {
                diagnostics = {
                    virtual_text = {
                        severity = vim.diagnostic.severity.ERROR,
                        spacing = 4,
                        prefix = "",
                    },
                },
                setup = {
                    autostart = true,
                },
                inlay_hints = { enabled = false },
                autoformat = true,
                format_notify = false,
            },
        },
        { "williamboman/mason.nvim", opts = {} },
        {
            "williamboman/mason-lspconfig.nvim",
            dependencies = { "williamboman/mason.nvim" },
            opts = {
                automatic_enable = true,
                automatic_installation = true,
            },
        },

        {
            "nvim-neo-tree/neo-tree.nvim",
            lazy = false,
            ---@module "neo-tree"
            ---@type neotree.Config
            opts = {
                close_if_last_window = true,
                -- popup_border_style = "winborder",
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
                        hide_gitignored = true,
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
                    group_empty_dirs = true,
                    hijack_netrw_behavior = "disabled",
                    use_libuv_file_watcher = true,
                },
            },
            keys = {
                { "<leader>e", "<cmd>Neotree toggle<cr>" },
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
        {
            "xiyaowong/virtcolumn.nvim",
        },

        {
            "shahshlok/vim-coach.nvim",
            dependencies = {
                "folke/snacks.nvim",
            },
            config = function() require("vim-coach").setup() end,
            keys = {
                { "<leader>?", "<cmd>VimCoach<cr>", desc = "Vim Coach" },
            },
        },
    },
}, opts)

-- Show LSP diagnostics on hover using new neovim 0.11 virtual lines
-- https://gpanders.com/blog/whats-new-in-neovim-0-11/#virtual-lines
vim.diagnostic.config({
    virtual_text = {
        severity = vim.diagnostic.severity.ERROR,
        spacing = 4,
        prefix = "",
    },
    virtual_lines = {
        current_line = true,
    },
    severity_sort = true,
    underline = true,
    float = {
        focusable = false,
        style = "minimal",
        border = "rounded",
        source = true,
        header = "",
    },
    update_in_insert = false,
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = tools.ui.diagnostics.error_cod,
            [vim.diagnostic.severity.WARN] = tools.ui.diagnostics.warn_cod,
            [vim.diagnostic.severity.INFO] = tools.ui.diagnostics.info_cod,
            [vim.diagnostic.severity.HINT] = tools.ui.diagnostics.hint_cod,
        },
    },
})

-- Show LSP diagnostics (inlay hints) in a hover window / popup
-- https://github.com/neovim/nvim-lspconfig/wiki/UI-Customization#show-line-diagnostics-automatically-in-hover-window
-- https://www.reddit.com/r/neovim/comments/1168p97/how_can_i_make_lspconfig_wrap_around_these_hints/
-- Time it takes to show the popup after you hover over the line with an error
vim.o.updatetime = 400

-- Time it takes for neovim to wait for completion of key sequence
vim.o.timeoutlen = 300

-- Max height of popups to 5 items
vim.o.pumheight = 5

-- LSP Folding
-- https://old.reddit.com/r/neovim/comments/1jmqd7t/sorry_ufo_these_7_lines_replaced_you/
vim.o.foldenable = true
vim.o.foldlevel = 99
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.o.foldtext = ""

-- Load .vimrc
vim.cmd([[
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc
]])
