vim.pack.add({
    "https://github.com/A7Lavinraj/fyler.nvim",
    version = "stable",
})

require("fyler").setup({
    views = {
        finder = {
            default_explorer = true,
            win = {
                kind = "replace",
            },
        },
    },
})

vim.keymap.set("n", "<leader>e", function()
    require("fyler").open({ kind = "split_left_most" })
end, { desc = "Open Fyler sidebar" })
