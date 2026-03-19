vim.lsp.enable("rust_analyzer")

return {
    {
        "nvim-treesitter/nvim-treesitter",
        opts = {
            ensure_installed = { "rust" },
        },
    },
    {
        "stevearc/conform.nvim",
        opts = {
            formatters_by_ft = {
                rust = { "rustfmt", lsp_format = "fallback" },
            },
        },
    },
    {
        "mfussenegger/nvim-lint",
        opts = {
            linters = {
                cargo = {
                    cmd = "cargo",
                    stdin = false,
                    args = { "check" },
                    stream = "both",
                    ignore_exitcode = false,
                    env = nil,
                },
            },
            linters_by_ft = {
                rust = { "cargo" },
            },
        },
    },
}
