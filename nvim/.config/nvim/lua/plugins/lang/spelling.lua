return {
    {
        "mason-org/mason.nvim",
        opts = {
            ensure_installed = {
                "codespell",
                "write-good",
                "harper-ls",
            },
        },
    },
    {
        "mason-org/mason-lspconfig.nvim",
        opts = {
            ensure_installed = {
                "harper_ls",
            },
        },
    },
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
