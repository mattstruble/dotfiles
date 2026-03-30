-- Note: hardtime.nvim listed nui.nvim as a dependency in the old config,
-- but nui.nvim is dropped in this migration (replaced by 0.12 extui).
-- hardtime works without nui; the hint popup feature will be unavailable.
vim.pack.add({ "https://github.com/m4xshen/hardtime.nvim" })
require("hardtime").setup({
    disabled_filetypes = {
        "qf", "netrw", "NvimTree", "lazy", "mason",
        "toggleterm", "oil", "snacks_terminal",
    },
    resetting_keys = {
        ["y"] = {},
        ["p"] = {},
        ["P"] = {},
    },
})
