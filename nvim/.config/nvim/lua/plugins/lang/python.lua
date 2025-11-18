local py = require("utils.python")

return {
    {
        "mason-org/mason.nvim",
        opts = {
            ensure_installed = {
                "ruff",
            },
        },
    },
    {
        "mason-org/mason-lspconfig.nvim",
        opts = {
            ensure_installed = {
                "ruff",
                "pyrefly",
            },
        },
    },
    {
        "mfussenegger/nvim-lint",
        opts = {
            linters_by_ft = {
                python = { "ruff" },
            },
        },
    },
    {
        "stevearc/conform.nvim",
        opts = {
            formatters_by_ft = {
                python = { "ruff_fix", "ruff_format", "ruff_organize_imports" },
            },
        },
    },
    {
        "stellarjmr/notebook_style.nvim",
        ft = "python",
        opts = {},
    },
}
