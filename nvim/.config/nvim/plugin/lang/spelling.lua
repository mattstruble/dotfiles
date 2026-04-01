local allowed_filetypes = { "markdown", "text", "gitcommit" }

vim.lsp.config("harper_ls", {
    root_dir = function(bufnr, on_dir)
        if vim.tbl_contains(allowed_filetypes, vim.bo[bufnr].filetype) then
            on_dir(vim.fn.getcwd())
        end
    end,
})

vim.lsp.enable("harper_ls")
