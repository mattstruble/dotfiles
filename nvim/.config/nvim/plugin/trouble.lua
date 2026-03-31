local loaded = false
local function ensure_loaded()
    if loaded then return end
    loaded = true
    local ok, err = pcall(function()
        vim.pack.add({ "https://github.com/folke/trouble.nvim" })
        require("trouble").setup({
            modes = { lsp = { win = { position = "right" } } },
        })
    end)
    if not ok then
        vim.notify("trouble: " .. tostring(err), vim.log.levels.ERROR)
    end
end

local map = vim.keymap.set
map("n", "<leader>xx", function()
    ensure_loaded(); vim.cmd("Trouble diagnostics toggle")
end, { desc = "Diagnostics (Trouble)" })
map("n", "<leader>xX", function()
    ensure_loaded(); vim.cmd("Trouble diagnostics toggle filter.buf=0")
end, { desc = "Buffer Diagnostics (Trouble)" })
map("n", "<leader>cs", function()
    ensure_loaded(); vim.cmd("Trouble symbols toggle")
end, { desc = "Symbols (Trouble)" })
map("n", "<leader>cS", function()
    ensure_loaded(); vim.cmd("Trouble lsp toggle")
end, { desc = "LSP references/definitions/... (Trouble)" })
map("n", "<leader>xL", function()
    ensure_loaded(); vim.cmd("Trouble loclist toggle")
end, { desc = "Location List (Trouble)" })
map("n", "<leader>xQ", function()
    ensure_loaded(); vim.cmd("Trouble qflist toggle")
end, { desc = "Quickfix List (Trouble)" })
map("n", "[q", function()
    ensure_loaded()
    if require("trouble").is_open() then
        require("trouble").prev({ skip_groups = true, jump = true })
    else
        local ok, err = pcall(vim.cmd.cprev)
        if not ok then vim.notify(err, vim.log.levels.ERROR) end
    end
end, { desc = "Previous Trouble/Quickfix Item" })
map("n", "]q", function()
    ensure_loaded()
    if require("trouble").is_open() then
        require("trouble").next({ skip_groups = true, jump = true })
    else
        local ok, err = pcall(vim.cmd.cnext)
        if not ok then vim.notify(err, vim.log.levels.ERROR) end
    end
end, { desc = "Next Trouble/Quickfix Item" })
