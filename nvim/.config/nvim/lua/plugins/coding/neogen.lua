return {
    "danymat/neogen",
    lazy = true,
    dependencies = {
        "nvim-treesitter/nvim-treesitter",
        "nvim-mini/mini.snippets",
    },
    opts = {
        snippet_engine = "mini",
        languages = {
            python = {
                template = {
                    annotation_convention = "reST",
                },
            },
        },
    },
    keys = {
        {
            "<leader>nf",
            ":lua require('neogen').generate()<cr>",
            desc = "Generate function docs",
        },
        {
            "<leader>nc",
            ":lua require('neogen').generate({type = 'class'})<cr>",
            desc = "Generate class docs",
        },
    },
}
