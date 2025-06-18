return {
    {
        "catppuccin/nvim",
        name = "catppuccin",
        priority = 1000,
        lazy = false,
        enabled = false,
        config = function() vim.cmd.colorscheme("catppuccin-mocha") end,
    },
    {
        "ribru17/bamboo.nvim",
        name = "bamboo",
        lazy = false,
        priority = 1000,
        config = function()
            require("bamboo").setup({
                transparent = true,
                dim_inactive = true,
                lualine = {
                    transparent = true,
                },
            })
            require("bamboo").load()
        end,
    },
}
