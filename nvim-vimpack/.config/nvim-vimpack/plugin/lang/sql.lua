-- vim-dadbod-ui: key-triggered database UI
local loaded = false
local function ensure_loaded()
    if loaded then return end
    vim.pack.add({
        "https://github.com/tpope/vim-dadbod",
        "https://github.com/kristijanhusak/vim-dadbod-completion",
        "https://github.com/kristijanhusak/vim-dadbod-ui",
    })
    loaded = true
end

vim.keymap.set("n", "<leader>vb", function()
    ensure_loaded()
    vim.cmd("DBUIToggle")
end, { desc = "View dadbod" })
