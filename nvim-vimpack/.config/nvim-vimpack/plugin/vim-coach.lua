vim.schedule(function()
    vim.pack.add({ "https://github.com/shahshlok/vim-coach.nvim" })
    require("vim-coach").setup()

    vim.keymap.set("n", "<leader>?", "<cmd>VimCoach<cr>", { desc = "Vim Coach" })
end)
