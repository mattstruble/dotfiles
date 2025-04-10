return {
    {
        "williamboman/mason.nvim",
        opts = {
            ensure_installed = {
                "tflint",
            },
        },
    },
    {
        "williamboman/mason-lspconfig.nvim",
        opts = {
            ensure_installed = {
                "tflint",
                "terraformls",
            },
        },
    },
    {
        "mfussenegger/nvim-lint",
        opts = {
            linters_by_ft = {
                terraform = { "tflint" },
                hcl = { "tflint" },
            },
        },
    },
    {
        "stevearc/conform.nvim",
        opts = {
            formatters_by_ft = {
                terraform = {
                    "terraform_fmt",
                    "trim_newlines",
                    "trim_whitespace",
                },
                hcl = { "terraform_fmt", "trim_newlines", "trim_whitespace" },
            },
        },
    },
}
