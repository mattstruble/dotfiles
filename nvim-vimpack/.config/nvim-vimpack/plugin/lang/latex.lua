vim.lsp.enable("texlab")

vim.api.nvim_create_autocmd("FileType", {
    pattern = "tex",
    once = true,
    callback = function()
        vim.g.papyrus_latex_engine = "pdflatex"  -- must be set before pack.add
        vim.g.papyrus_viewer = "zathura"          -- must be set before pack.add
        vim.pack.add({ "https://github.com/abeleinin/papyrus" })

        local map = vim.keymap.set
        map("n", "<leader>pc", ":PapyrusCompile<cr>", { desc = "Papyrus Compile" })
        map("n", "<leader>pa", ":PapyrusAutoCompile<cr>", { desc = "Papyrus Auto Compile" })
        map("n", "<leader>pv", ":PapyrusView<cr>", { desc = "Papyrus View" })
        map("n", "<leader>ps", ":PapyrusStart<cr>", { desc = "Papyrus Start" })
    end,
})
