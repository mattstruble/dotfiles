return {
    {
        "williamboman/mason.nvim",
        opts = {
            ensure_installed = {
                "nixpkgs-fmt",
                -- "nil_ls",
                "nixfmt",
            },
        },
    },
    {
        "williamboman/mason-lspconfig.nvim",
        opts = {
            ensure_installed = {
                -- "nil_ls",
            },
        },
    },
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
                nix = { "nixfmt", "nixpkgs_fmt" },
            },
        },
    },
}
