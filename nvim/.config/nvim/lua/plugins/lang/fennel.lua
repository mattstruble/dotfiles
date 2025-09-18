return {
    { "Olical/conjure" },
    { "atweiden/vim-fennel" },
    {
        "mason-org/mason.nvim",
        opts = {
            ensure_installed = {
                "fennel-ls",
            },
        },
    },
    {
        "mason-org/mason-lspconfig.nvim",
        opts = {
            ensure_installed = {
                "fennel-ls",
            },
        },
    },
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
