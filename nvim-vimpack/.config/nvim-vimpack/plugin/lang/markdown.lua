vim.lsp.enable("markdown_oxide")

vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    once = true,
    callback = function()
        local ok, err = pcall(vim.pack.add, { "https://github.com/mzlogin/vim-markdown-toc" })
        if not ok then
            vim.notify("vim-markdown-toc: " .. tostring(err), vim.log.levels.ERROR)
            return
        end
        vim.keymap.set("n", "<leader>mtoc", "<cmd>GenTocMarked<cr>", { desc = "Generate Markdown TOC" })
    end,
})
