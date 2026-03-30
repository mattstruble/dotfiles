local loaded = false
local function ensure_loaded()
    if loaded then return end
    vim.pack.add({ "https://github.com/MagicDuck/grug-far.nvim" })
    require("grug-far").setup({ headerMaxWidth = 80 })
    loaded = true
end

vim.keymap.set({ "n", "x" }, "<leader>sr", function()
    ensure_loaded()
    local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
    require("grug-far").open({
        transient = true,
        prefills = { filesFilter = ext and ext ~= "" and "*." .. ext or nil },
    })
end, { desc = "Search and Replace" })
