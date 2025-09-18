return {
    {
        "saghen/blink.cmp",
        dependencies = {
            { "nvim-mini/mini.snippets" },
        },
        opts = {
            enabled = function()
                return not vim.tbl_contains(
                    { "markdown", "minifiles" },
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
        },
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
