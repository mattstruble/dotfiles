vim.pack.add({ "https://github.com/actionshrimp/direnv.nvim" })
require("direnv-nvim").setup({
    async = true,
    on_direnv_finished = function()
        -- Guard: LspRestart may not exist if lspconfig hasn't registered commands yet
        -- (e.g., direnv fires on first BufEnter before any LSP attaches)
        pcall(vim.cmd, "LspRestart")
    end,
})
