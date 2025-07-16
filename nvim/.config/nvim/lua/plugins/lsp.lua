return {

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
        "zeioth/garbage-day.nvim",
        dependencies = "neovim/nvim-lspconfig",
        event = "VeryLazy",
    },
    { import = "plugins.lang" },
}
