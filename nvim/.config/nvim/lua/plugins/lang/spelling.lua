vim.lsp.enable("harper_ls")

return {
    {
        "mfussenegger/nvim-lint",
        opts = {
            linters_by_ft = {
                ["*"] = { "codespell" },
                markdown = { "write_good" },
                text = { "write_good" },
            },
        },
    },
    {
        "cappyzawa/trim.nvim",
        opts = {},
    },
}
