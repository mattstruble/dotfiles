return {
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
}
