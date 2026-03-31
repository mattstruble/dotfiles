vim.schedule(function()
    vim.pack.add({
        "https://github.com/rafamadriz/friendly-snippets",
        "https://github.com/nvim-mini/mini.snippets",
    })
    local mini_snippets = require("mini.snippets")
    require("mini.snippets").setup({
        snippets = { mini_snippets.gen_loader.from_lang() },
    })
end)
