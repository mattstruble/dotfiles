vim.lsp.enable("nixd")

return {
    {
        "mfussenegger/nvim-lint",
        opts = {
            linters_by_ft = {
                nix = { "nix" },
            },
        },
    },
    {
        "stevearc/conform.nvim",
        opts = {
            formatters_by_ft = {
                nix = { "nixfmt" },
            },
        },
    },
}
