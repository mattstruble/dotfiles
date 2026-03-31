-- Tier 3: undotree (not built-in in stable 0.12 despite changelog)
local loaded = false
local function ensure_loaded()
    if loaded then return end
    loaded = true
    local ok, err = pcall(vim.pack.add, { "https://github.com/mbbill/undotree" })
    if not ok then
        vim.notify("undotree: " .. tostring(err), vim.log.levels.ERROR)
    end
end

vim.keymap.set("n", "<leader>uu", function()
    ensure_loaded()
    vim.cmd("UndotreeToggle")
end, { desc = "Undo Tree" })
