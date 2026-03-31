vim.pack.add({ "https://github.com/laytan/cloak.nvim" })
require("cloak").setup({
    enabled = true,
    cloak_character = "*",
    highlight_group = "Comment",
    patterns = {
        {
            file_pattern = { ".env*", "wrangler.toml", ".dev.vars" },
            cloak_pattern = { "=.*", ":.+", "-.+" },
        },
    },
})

vim.keymap.set("n", "<leader>cv", ":CloakPreviewLine<cr>", { desc = "Cloak View Line" })
