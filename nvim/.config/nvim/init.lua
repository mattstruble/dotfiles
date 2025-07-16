--------------------------
-- LAZY SETUP
--------------------------
require("config.globals")

require("config.lazy")

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

-- Show LSP diagnostics (inlay hints) in a hover window / popup
-- https://github.com/neovim/nvim-lspconfig/wiki/UI-Customization#show-line-diagnostics-automatically-in-hover-window
-- https://www.reddit.com/r/neovim/comments/1168p97/how_can_i_make_lspconfig_wrap_around_these_hints/
-- Time it takes to show the popup after you hover over the line with an error
vim.o.updatetime = 400

-- Time it takes for neovim to wait for completion of key sequence
vim.o.timeoutlen = 300

-- Max height of popups to 5 items
vim.o.pumheight = 5

-- LSP Folding
-- https://old.reddit.com/r/neovim/comments/1jmqd7t/sorry_ufo_these_7_lines_replaced_you/
vim.o.foldenable = true
vim.o.foldlevel = 99
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.o.foldtext = ""

-- Load .vimrc
vim.cmd([[
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc
]])
