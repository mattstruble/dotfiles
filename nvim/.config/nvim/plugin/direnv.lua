vim.pack.add({ "https://github.com/actionshrimp/direnv.nvim" })
require("direnv-nvim").setup({
    async = true,
    on_direnv_finished = function()
        -- Restart all active LSP clients after direnv updates the environment
        -- Uses native 0.12 API (lspconfig's :LspRestart is suppressed when :lsp exists)
        for _, client in ipairs(vim.lsp.get_clients()) do
            vim.cmd("lsp restart " .. client.name)
        end
    end,
})
