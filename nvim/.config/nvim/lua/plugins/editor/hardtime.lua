return {
    "m4xshen/hardtime.nvim",
    dependencies = { "MunifTanjim/nui.nvim", "nvim-lua/plenary.nvim" },
    opts = {
        disabled_filetypes = {
            "qf",
            "netrw",
            "NvimTree",
            "lazy",
            "mason",
            "toggleterm",
            "oil",
            "snacks_terminal",
        },
        resetting_keys = {
            ["y"] = {},
            ["p"] = {},
            ["P"] = {},
        },
    },
}
