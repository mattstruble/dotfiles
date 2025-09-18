return {
    {
        "mason-org/mason.nvim",
        opts = {
            ensure_installed = {
                "sqlfluff",
                "sqlls",
            },
        },
    },
    {
        "mason-org/mason-lspconfig.nvim",
        opts = {
            ensure_installed = {
                "sqlls",
            },
        },
    },
    {
        "mfussenegger/nvim-lint",
        opts = {
            linters_by_ft = {
                sql = { "sqruff" },
            },
        },
    },
    {
        "stevearc/conform.nvim",
        opts = {
            formatters_by_ft = {
                sql = { "sqruff" },
            },
        },
    },
    {
        "kristijanhusak/vim-dadbod-ui",
        dependencies = {
            "tpope/vim-dadbod",
            "kristijanhusak/vim-dadbod-completion",
        },
        lazy = true,
        keys = {
            {
                "<leader>vb",
                "<cmd>DBUIToggle<cr>",
                desc = "View dadbod",
            },
        },
    },
}
