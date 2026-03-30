vim.pack.add({
    "https://github.com/nvim-mini/mini.snippets",
    { src = "https://github.com/saghen/blink.cmp", version = vim.version.range("1.x") },
    "https://github.com/neovim/nvim-lspconfig",
})

require("blink.cmp").setup({
    enabled = function()
        return not vim.tbl_contains(
            { "markdown", "minifiles", "opencode", "opencode_output" },
            vim.bo.filetype
        )
    end,
    snippets = { preset = "mini_snippets" },
    completion = {
        trigger = { show_on_insert_on_trigger_character = false },
        ghost_text = { show_with_menu = false },
    },
    sources = {
        default = { "lsp", "path", "snippets", "buffer" },
    },
    keymap = {
        preset = "none",
        ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-e>"] = { "hide" },
        ["<C-y>"] = { "select_and_accept" },
        ["<C-n>"] = { "select_next", "fallback" },
        ["<C-p>"] = { "select_prev", "fallback" },
        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
        ["<CR>"] = { "accept", "fallback" },
    },
})
