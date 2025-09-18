return {
    {
        "mason-org/mason.nvim",
        opts = {
            ensure_installed = {
                "ltex-ls",
            },
        },
    },
    {
        "mason-org/mason-lspconfig.nvim",
        opts = {
            ensure_installed = {
                "ltex",
            },
        },
    },
    {
        "mfussenegger/nvim-lint",
        opts = {
            linters_by_ft = {
                tex = { "lacheck" },
            },
        },
    },
    {
        "stevearc/conform.nvim",
        opts = {
            formatters_by_ft = {
                tex = { "tex-fmt" },
            },
        },
    },
    {
        "abeleinin/papyrus",
        lazy = true,
        ft = "tex",
        config = function()
            vim.g.papyrus_latex_engine = "pdflatex"
            vim.g.papyrus_viewer = "zathura"
        end,
        -- stylua: ignore
        keys = {
            { "<leader>pc", ":PapyrusCompile<cr>",     desc = "Papyrus Compile" },
            { "<leader>pa", ":PapyrusAutoCompile<cr>", desc = "Papyrus Auto Compile" },
            { "<leader>pv", ":PapyrusView<cr>",        desc = "Papyrus View" },
            { "<leader>ps", ":PapyrusStart<cr>",       desc = "Papyrus Start" }
        },
    },
}
