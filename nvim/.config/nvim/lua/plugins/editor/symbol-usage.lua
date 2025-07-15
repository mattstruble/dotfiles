return {
    "Wansmer/symbol-usage.nvim",
    name = "symbol-usage",
    event = "LspAttach",
    opts = {
        vt_position = "end_of_line",
        request_pending_text = false,
    },
}
