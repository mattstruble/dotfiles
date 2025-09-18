return {
    {
        "mason-org/mason.nvim",
        opts = {
            ensure_installed = {
                "ansible-lint",
                "ansible-language-server",
            },
        },
    },
    {
        "mason-org/mason-lspconfig.nvim",
        opts = {
            ensure_installed = {
                "ansiblels",
            },
        },
    },
    {
        "mfussenegger/nvim-lint",
        opts = {
            linters_by_ft = {
                ansible = { "ansible_lint" },
            },
        },
    },
}
