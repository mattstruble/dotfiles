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
                        Error = " ",
                        Warn = " ",
                        Hint = " ",
                        Info = " ",
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
                { "saghen/blink.compat", lazy = true, version = false },
            },
            opts = {
                completion = {
                    trigger = {
                        show_on_insert_on_trigger_character = false,
                    },
                },
                sources = {
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
                    autostart = false,
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
                inlay_hints = { enabled = false },
                autoformat = true,
                format_notify = false,
            },
        },

        {
            "nvim-neo-tree/neo-tree.nvim",
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

        -- cache plugins so they load faster
        {
            "lewis6991/impatient.nvim",
            lazy = false,
            priority = 1000, -- load this first
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

-- Automatically jump to the last cursor spot in file before exiting
vim.api.nvim_create_autocmd("BufReadPost", {
    callback = function()
        local mark = vim.api.nvim_buf_get_mark(0, '"')
        local lcount = vim.api.nvim_buf_line_count(0)
        if mark[1] > 0 and mark[1] <= lcount then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end,
})

-- Show LSP diagnostics on hover using new neovim 0.11 virtual lines
-- https://gpanders.com/blog/whats-new-in-neovim-0-11/#virtual-lines
vim.diagnostic.config({
    virtual_text = false,
    virtual_lines = {
        current_line = true,
    },
    severity_sort = true,
    underline = true,
    signs = true
})
