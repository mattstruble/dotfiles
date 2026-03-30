vim.pack.add({ "https://github.com/Wansmer/symbol-usage.nvim" })
require("symbol-usage").setup({
    vt_position = "end_of_line",
    request_pending_text = false,
})
