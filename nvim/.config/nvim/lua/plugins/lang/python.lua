vim.lsp.enable("ty")

return {
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
