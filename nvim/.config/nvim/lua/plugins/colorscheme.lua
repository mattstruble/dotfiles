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
        enabled = true,
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
    {
        "alexkotusenko/nightgem.nvim",
        lazy = false,
        priority = 1000,
        enabled = false,
        config = function()
            require("nightgem").setup()
            -- vim.cmd("colorscheme nightgem")
        end,
    },
    {
        "rose-pine/neovim",
        lazy = false,
        priority = 1000,
        name = "rose-pine",
        enabled = false,
    },
    {
        "LazyVim/LazyVim",
        opts = {
            colorscheme = "bamboo",
        },
    },
}
