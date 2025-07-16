return {
    "actionshrimp/direnv.nvim",
    opts = {
        async = true,
        on_direnv_finished = function()
            -- You may also want to pair this with `autostart = false` in any `lspconfig` calls
            -- vim.cmd("LspStart")
            vim.cmd("LspRestart")
        end,
    },
}
