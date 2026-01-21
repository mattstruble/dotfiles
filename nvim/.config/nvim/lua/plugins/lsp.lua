return {
    {
        "saghen/blink.cmp",
        dependencies = {
            { "nvim-mini/mini.snippets" },
        },
        opts = {
            enabled = function()
                return not vim.tbl_contains(
                    { "markdown", "minifiles", "opencode", "opencode_output" },
                    vim.bo.filetype
                )
            end,
            snippets = { preset = "mini_snippets" },
            completion = {
                trigger = {
                    show_on_insert_on_trigger_character = false,
                },
            },
            sources = {
                default = { "lsp", "path", "snippets", "buffer" },
            },
            keymap = {
                preset = "none",
                ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
                ["<C-e>"] = { "hide" },
                ["<C-y>"] = { "select_and_accept" },
                ["<C-n>"] = { "select_next", "fallback" },
                ["<C-p>"] = { "select_prev", "fallback" },
                ["<C-b>"] = { "scroll_documentation_up", "fallback" },
                ["<C-f>"] = { "scroll_documentation_down", "fallback" },
                ["<CR>"] = { "accept", "fallback" },
            },
        },
        config = function(_, opts)
            require("blink.cmp").setup(opts)

            -- Hide Copilot suggestions when blink.cmp menu is open
            vim.api.nvim_create_autocmd("User", {
                pattern = "BlinkCmpMenuOpen",
                callback = function()
                    vim.b.copilot_suggestion_hidden = true
                end,
            })

            vim.api.nvim_create_autocmd("User", {
                pattern = "BlinkCmpMenuClose",
                callback = function()
                    vim.b.copilot_suggestion_hidden = false
                end,
            })
        end,
    },
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "mason-org/mason.nvim",
            "mason-org/mason-lspconfig.nvim",
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
    { "mason-org/mason.nvim", opts = {} },
    {
        "mason-org/mason-lspconfig.nvim",
        dependencies = { "mason-org/mason.nvim" },
        opts = {
            automatic_enable = true,
            automatic_installation = true,
        },
    },
    {
        "zeioth/garbage-day.nvim",
        dependencies = "neovim/nvim-lspconfig",
        event = "VeryLazy",
    },
    { import = "plugins.lang" },
}
