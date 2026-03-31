local loaded = false
local function ensure_loaded()
    if loaded then return end
    loaded = true
    local ok, err = pcall(vim.pack.add, { "https://github.com/lucidph3nx/nvim-sops" })
    if not ok then
        vim.notify("nvim-sops: " .. tostring(err), vim.log.levels.ERROR)
    end
end

vim.keymap.set("n", "<leader>fe", function()
    ensure_loaded()
    vim.cmd.SopsEncrypt()
end, { desc = "File Encrypt" })

vim.keymap.set("n", "<leader>fd", function()
    ensure_loaded()
    vim.cmd.SopsDecrypt()
end, { desc = "File Decrypt" })
