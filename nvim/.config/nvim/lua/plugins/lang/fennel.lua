vim.lsp.enable("fennel_ls")

return {
    {
        "mfussenegger/nvim-lint",
        opts = {
            linters_by_ft = {
                fennel = { "fennel" },
            },
        },
    },
    {
        "stevearc/conform.nvim",
        opts = {
            formatters_by_ft = {
                fennel = { "fnlfmt" },
            },
        },
    },
}
