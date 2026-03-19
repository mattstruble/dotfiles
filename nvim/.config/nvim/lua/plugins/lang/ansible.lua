vim.lsp.enable("ansiblels")

return {
    {
        "mfussenegger/nvim-lint",
        opts = {
            linters_by_ft = {
                ansible = { "ansible_lint" },
            },
        },
    },
}
