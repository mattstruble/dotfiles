local loaded = false
local function ensure_loaded()
    if loaded then return end
    vim.pack.add({ "https://github.com/lucidph3nx/nvim-sops" })
    loaded = true
end

vim.keymap.set("n", "<leader>fe", function()
    ensure_loaded()
    vim.cmd.SopsEncrypt()
end, { desc = "File Encrypt" })

vim.keymap.set("n", "<leader>fd", function()
    ensure_loaded()
    vim.cmd.SopsDecrypt()
end, { desc = "File Decrypt" })
