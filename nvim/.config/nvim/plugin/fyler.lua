vim.pack.add({
    { src = "https://github.com/A7Lavinraj/fyler.nvim", version = "stable" },
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

vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
        if vim.fn.argc() == 0 then
            require("fyler").open({ kind = "replace" })
        end
    end,
})

vim.keymap.set("n", "<leader>e", function()
    require("fyler").open({ kind = "split_left_most" })
end, { desc = "Open Fyler sidebar" })
