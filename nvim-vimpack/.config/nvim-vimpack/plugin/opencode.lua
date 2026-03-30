local loaded = false
local function ensure_loaded()
    if loaded then return end
    vim.pack.add({ "https://github.com/NickvanDyke/opencode.nvim" })
    vim.g.opencode_opts = { provider = { enabled = "tmux" } }
    loaded = true
end

vim.keymap.set({ "n", "x" }, "<leader>o", function()
    ensure_loaded()
    require("opencode").select()
end, { desc = "OpenCode select" })
