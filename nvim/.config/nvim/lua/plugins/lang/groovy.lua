return {
    {
        "mason-org/mason.nvim",
        opts = {
            "groovy-language-server",
            "npm-groovy-lint",
        },
    },
    {
        "mason-org/mason-lspconfig.nvim",
        opts = {
            "groovyls",
        },
    },
    {
        "mfussenegger/nvim-lint",
        opts = {
            linters_by_ft = {
                groovy = { "npm-groovy-lint" },
            },
        },
    },
    {
        "stevearc/conform.nvim",
        opts = {
            formatters_by_ft = {
                groovy = { "npm-groovy-lint" },
            },
        },
    },
    {
        "ckipp01/nvim-jenkinsfile-linter",
        lazy = true,
        ft = "groovy",
        dependencies = { "nvim-lua/plenary.nvim" },
    },
}
