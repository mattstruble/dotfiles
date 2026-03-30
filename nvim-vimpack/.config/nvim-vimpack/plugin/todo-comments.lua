vim.schedule(function()
    vim.pack.add({ "https://github.com/folke/todo-comments.nvim" })
    require("todo-comments").setup({})

    local map = vim.keymap.set
    map("n", "]t", function() require("todo-comments").jump_next() end, { desc = "Next Todo Comment" })
    map("n", "[t", function() require("todo-comments").jump_prev() end, { desc = "Previous Todo Comment" })
    map("n", "<leader>xt", "<cmd>Trouble todo toggle<cr>", { desc = "Todo (Trouble)" })
    map("n", "<leader>xT", "<cmd>Trouble todo toggle filter = {tag = {TODO,FIX,FIXME}}<cr>", { desc = "Todo/Fix/Fixme (Trouble)" })
    map("n", "<leader>st", function() require("todo-comments.fzf").todo() end, { desc = "Todo" })
    map("n", "<leader>sT", function()
        require("todo-comments.fzf").todo({ keywords = { "TODO", "FIX", "FIXME" } })
    end, { desc = "Todo/Fix/Fixme" })
end)
