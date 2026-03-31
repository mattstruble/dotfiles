vim.schedule(function()
    vim.pack.add({ "https://github.com/rachartier/tiny-glimmer.nvim" })
    require("tiny-glimmer").setup({
        enabled = true,
        disable_warnings = true,
        refresh_interval_ms = 8,
        overwrite = {
            auto_map = true,
            yank = { enabled = true, default_animation = "fade" },
            search = {
                enabled = true,
                default_animation = "pulse",
                next_mapping = "n",
                prev_mapping = "N",
            },
            paste = {
                enabled = true,
                default_animation = "reverse_fade",
                paste_mapping = "p",
                Paste_mapping = "P",
            },
            undo = { enabled = false },
            redo = { enabled = false },
        },
    })
end)
