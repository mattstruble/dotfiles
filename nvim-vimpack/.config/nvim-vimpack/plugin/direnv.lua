vim.pack.add({ "https://github.com/actionshrimp/direnv.nvim" })
require("direnv-nvim").setup({
    async = true,
    on_direnv_finished = function()
        vim.cmd("LspRestart")
    end,
})
