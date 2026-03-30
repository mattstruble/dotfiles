vim.pack.add({ "https://github.com/ribru17/bamboo.nvim" })
require("bamboo").setup({
    transparent = true,
    dim_inactive = true,
    lualine = {
        transparent = true,
    },
})
require("bamboo").load()
