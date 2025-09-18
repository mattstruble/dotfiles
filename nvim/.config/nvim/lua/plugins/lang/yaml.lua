return {
    {
        "mason-org/mason.nvim",
        opts = {
            ensure_installed = {
                "yamllint",
                "yamlfmt",
            },
        },
    },
    {
        "mason-org/mason-lspconfig.nvim",
        opts = {
            ensure_installed = {
                "yamlls",
            },
        },
    },
    {
        "mfussenegger/nvim-lint",
        opts = {
            linters_by_ft = {
                yaml = { "yamllint" },
            },
        },
    },
    {
        "stevearc/conform.nvim",
        opts = {
            formatters_by_ft = {
                yaml = { "yamlfmt", "trim_newlines" },
            },
        },
    },
}
