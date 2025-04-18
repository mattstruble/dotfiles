return {
    {
        "williamboman/mason.nvim",
        opts = {
            ensure_installed = {
                "codespell",
                "write-good",
                "harper-ls",
            },
        },
    },
    {
        "williamboman/mason-lspconfig.nvim",
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
                ["*"] = { "codespell", "write_good" },
            },
        },
    },
    {
        "cappyzawa/trim.nvim",
        opts = {},
    },
}
