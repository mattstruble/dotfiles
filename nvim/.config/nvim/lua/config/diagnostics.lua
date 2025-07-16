require("config.globals")

-- Show LSP diagnostics on hover using new neovim 0.11 virtual lines
-- https://gpanders.com/blog/whats-new-in-neovim-0-11/#virtual-lines
vim.diagnostic.config({
    virtual_text = {
        severity = vim.diagnostic.severity.ERROR,
        spacing = 4,
        prefix = "",
    },
    virtual_lines = {
        current_line = true,
    },
    severity_sort = true,
    underline = true,
    float = {
        focusable = false,
        style = "minimal",
        border = "rounded",
        source = true,
        header = "",
    },
    update_in_insert = false,
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = tools.ui.diagnostics.error_cod,
            [vim.diagnostic.severity.WARN] = tools.ui.diagnostics.warn_cod,
            [vim.diagnostic.severity.INFO] = tools.ui.diagnostics.info_cod,
            [vim.diagnostic.severity.HINT] = tools.ui.diagnostics.hint_cod,
        },
    },
})
