return {
    "m4xshen/hardtime.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
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
