vim.lsp.enable("markdown_oxide")

vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    once = true,
    callback = function()
        vim.pack.add({ "https://github.com/mzlogin/vim-markdown-toc" })
        vim.keymap.set("n", "<leader>mtoc", "<cmd>GenTocMarked<cr>", { desc = "Generate Markdown TOC" })
    end,
})
