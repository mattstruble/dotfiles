return {
    {
        "axkirillov/hbac.nvim",
        lazy = true,
        event = "BufAdd",
        config = function() require("hbac").setup() end,
    },
}
