local py = require("utils.python")

return {
    {
        "williamboman/mason.nvim",
        opts = {
            ensure_installed = {
                "ruff",
                "debugpy",
            },
        },
    },
    {
        "williamboman/mason-lspconfig.nvim",
        opts = {
            ensure_installed = {
                "ruff",
                "basedpyright",
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
}
