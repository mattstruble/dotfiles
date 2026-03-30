local loaded = false
local function ensure_loaded()
    if loaded then return end
    vim.pack.add({ "https://github.com/dmtrKovalenko/fff.nvim" })
    loaded = true
end

local map = vim.keymap.set
map("n", "<leader>ff", function() ensure_loaded(); require("fff").find_files() end, { desc = "Find Files" })
map("n", "<leader>fg", function() ensure_loaded(); require("fff").live_grep() end, { desc = "Live Grep" })
map("n", "<leader>fr", function() ensure_loaded(); require("fff").find_files() end, { desc = "Find Files (recent)" })
map("n", "<leader>fc", function()
    ensure_loaded()
    require("fff").find_files_in_dir(vim.fn.stdpath("config"))
end, { desc = "Find Config File" })
map("n", "<leader>sg", function() ensure_loaded(); require("fff").live_grep() end, { desc = "Grep" })
map("n", "<leader>sw", function()
    ensure_loaded()
    require("fff").live_grep({ query = vim.fn.expand("<cword>") })
end, { desc = "Grep Word (cword)" })
map("n", "<leader>sW", function()
    ensure_loaded()
    require("fff").live_grep({ query = vim.fn.expand("<cWORD>") })
end, { desc = "Grep Word (cWORD)" })
map("v", "<leader>sw", function()
    ensure_loaded()
    vim.cmd('noau normal! "vy')
    require("fff").live_grep({ query = vim.fn.getreg("v") })
end, { desc = "Grep Selection" })
