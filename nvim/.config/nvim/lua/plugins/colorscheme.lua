return {
    {
        "catppuccin/nvim",
        name = "catppuccin",
        priority = 1000,
        lazy = false,
        enabled = true,
        config = function()
            vim.cmd.colorscheme("catppuccin-mocha")
        end,
    },
}
