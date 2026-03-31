vim.lsp.enable("helm_ls")

vim.api.nvim_create_autocmd("FileType", {
    pattern = "helm",
    once = true,
    callback = function()
        vim.pack.add({ "https://github.com/qvalentin/helm-ls.nvim" })
    end,
})
