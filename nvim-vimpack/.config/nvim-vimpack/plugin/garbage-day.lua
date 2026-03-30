-- Deferred: garbage-day auto-stops idle LSP clients
vim.schedule(function()
    vim.pack.add({ "https://github.com/zeioth/garbage-day.nvim" })
end)
