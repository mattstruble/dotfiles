vim.lsp.enable("ty")
vim.lsp.enable("ruff")

vim.api.nvim_create_autocmd("FileType", {
    pattern = "python",
    once = true,
    callback = function()
        vim.pack.add({ "https://github.com/stellarjmr/notebook_style.nvim" })
        require("notebook_style").setup({})
    end,
})
