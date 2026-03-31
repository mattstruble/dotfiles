-- Eager (no FileType guard): lazydev must be set up before lua_ls attaches,
-- which happens on the same FileType event -- ordering is not guaranteed.
vim.pack.add({ "https://github.com/folke/lazydev.nvim" })
require("lazydev").setup({
    library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        { path = "snacks.nvim", words = { "Snacks" } },
    },
})
