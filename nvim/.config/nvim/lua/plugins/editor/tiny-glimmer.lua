return {
    "rachartier/tiny-glimmer.nvim",
    event = "VeryLazy",
    priority = 10,
    name = "tiny-glimmer",
    opts = {
        enabled = true,
        disable_warnings = true,
        refresh_interval_ms = 8,

        overwrite = {
            auto_map = true,

            yank = {
                enabled = true,
                default_animation = "fade",
            },

            search = {
                enabled = true,
                default_animation = "pulse",
                next_mapping = "n",
                prev_mapping = "N",
            },

            paste = {
                enabled = true,
                default_animation = "reverse_fade",
                paste_mapping = "p", -- Paste after cursor
                Paste_mapping = "P", -- Paste before cursor
            },

            undo = {
                enabled = false,
                default_animation = {
                    name = "fade",
                    settings = {
                        from_color = "DiffDelete",
                        max_duration = 500,
                        min_duration = 500,
                    },
                },
                undo_mapping = "u",
            },

            redo = {
                enabled = false,
                default_animation = {
                    name = "fade",
                    settings = {
                        from_color = "DiffAdd",
                        max_duration = 500,
                        min_duration = 500,
                    },
                },
                redo_mapping = "<c-r>",
            },
        },
    },
}
