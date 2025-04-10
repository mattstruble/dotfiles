return {
    {
        "williamboman/mason.nvim",
        opts = {
            "shfmt",
            "bash-language-server",
        },
    },
    {
        "williamboman/mason-lspconfig.nvim",
        opts = {
            "bashls",
        },
    },
    {
        "mfussenegger/nvim-lint",
        opts = {
            linters_by_ft = {
                sh = { "shellcheck" },
                bash = { "shellcheck" },
            },
        },
    },
    {
        "stevearc/conform.nvim",
        opts = {
            formatters_by_ft = {
                sh = { "shfmt", "shellharden" },
                bash = { "shfmt", "shellharden" },
            },
        },
    },
}
