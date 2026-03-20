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
            "<leader>cgf",
            ":lua require('neogen').generate()<cr>",
            desc = "Generate function docs",
        },
        {
            "<leader>cgc",
            ":lua require('neogen').generate({type = 'class'})<cr>",
            desc = "Generate class docs",
        },
    },
}
