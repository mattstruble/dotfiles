local loaded = false
local function ensure_loaded()
    if loaded then return end
    loaded = true
    local ok, err = pcall(function()
        -- Set global BEFORE loading (replaces lazy.nvim `init` pattern)
        vim.g.opencode_opts = { provider = { enabled = "tmux" } }
        vim.pack.add({ "https://github.com/NickvanDyke/opencode.nvim" })
    end)
    if not ok then
        vim.notify("opencode: " .. tostring(err), vim.log.levels.ERROR)
    end
end

vim.keymap.set({ "n", "x" }, "<leader>o", function()
    ensure_loaded()
    require("opencode").select()
end, { desc = "OpenCode select" })
