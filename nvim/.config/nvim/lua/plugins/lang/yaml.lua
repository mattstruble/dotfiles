vim.lsp.enable("yamlls")

return {
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
