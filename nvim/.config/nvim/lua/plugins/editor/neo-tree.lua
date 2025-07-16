return {
    "nvim-neo-tree/neo-tree.nvim",
    ---@module "neo-tree"
    ---@type neotree.Config
    opts = {
        close_if_last_window = true,
        default_component_configs = {
            git_status = {
                symbols = {
                    unstaged = "✗",
                    staged = "✓",
                    unmerged = "",
                    renamed = "➜",
                    untracked = "★",
                    deleted = "",
                    ignored = "◌",
                },
            },
        },
        window = {
            mappings = {
                ["a"] = {
                    "add",
                    config = {
                        show_path = "relative",
                    },
                },
            },
        },
        filesystem = {
            filtered_items = {
                hide_dotfiles = false,
                hide_gitignored = true,
                hide_by_pattern = {
                    ".git",
                },
                always_show = {
                    ".gitignore",
                    ".github",
                },
                never_show = {
                    ".DS_Store",
                    "thumbs.db",
                },
                never_show_by_pattern = {
                    ".null-ls_*",
                },
            },
            follow_current_file = {
                enabled = true,
            },
            group_empty_dirs = true,
            hijack_netrw_behavior = "disabled",
            use_libuv_file_watcher = true,
        },
    },

    keys = {
        { "<leader>e", "<cmd>Neotree toggle<cr>" },
    },
}
