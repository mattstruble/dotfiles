return {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-mini/mini.icons" },
    opts = {
        disable_netrw = true,
        hijack_netrw = true,
        filters = {
            dotfiles = false,
            git_ignored = true,
            custom = {
                "^\\.git$",
                "^\\.DS_Store$",
                "^thumbs\\.db$",
                "^\\.null-ls_.*",
            },
        },
        update_focused_file = {
            enable = true,
        },
        renderer = {
            group_empty = true,
            highlight_git = "name",
            icons = {
                show = {
                    git = false,
                },
                glyphs = {
                    folder = {
                        arrow_closed = "",
                        arrow_open = "",
                    },
                    git = {
                        unstaged = "✗",
                        staged = "✓",
                        unmerged = "",
                        renamed = "➜",
                        untracked = "★",
                        deleted = "",
                        ignored = "◌",
                    },
                },
            },
        },
        filesystem_watchers = {
            enable = true,
        },
    },
    keys = {
        { "<leader>e", "<cmd>NvimTreeToggle<cr>" },
    },
}
