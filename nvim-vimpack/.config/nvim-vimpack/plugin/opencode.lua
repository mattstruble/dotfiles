local loaded = false
local function ensure_loaded()
    if loaded then return end
    -- Set global BEFORE loading (replaces lazy.nvim `init` pattern)
    vim.g.opencode_opts = { provider = { enabled = "tmux" } }
    vim.pack.add({ "https://github.com/NickvanDyke/opencode.nvim" })
    loaded = true
end

vim.keymap.set({ "n", "x" }, "<leader>o", function()
    ensure_loaded()
    require("opencode").select()
end, { desc = "OpenCode select" })
