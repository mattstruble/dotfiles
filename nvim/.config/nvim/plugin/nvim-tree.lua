local loaded = false
local function ensure_loaded()
    if loaded then return end
    loaded = true
    local ok, err = pcall(function()
        vim.pack.add({ "https://github.com/nvim-tree/nvim-tree.lua" })
        require("nvim-tree").setup({
            disable_netrw = true,
            hijack_netrw = true,
            filters = {
                dotfiles = false,
                git_ignored = true,
                custom = { "^\\.git$", "^\\.DS_Store$", "^thumbs\\.db$", "^\\.null-ls_.*" },
            },
            update_focused_file = { enable = true },
            renderer = {
                group_empty = true,
                highlight_git = "name",
                icons = {
                    show = { git = false },
                    glyphs = {
                        folder = { arrow_closed = "", arrow_open = "" },
                        git = {
                            unstaged = "✗", staged = "✓", unmerged = "",
                            renamed = "➜", untracked = "★", deleted = "", ignored = "◌",
                        },
                    },
                },
            },
            filesystem_watchers = { enable = true },
        })
    end)
    if not ok then
        vim.notify("nvim-tree: " .. tostring(err), vim.log.levels.ERROR)
    end
end

vim.keymap.set("n", "<leader>e", function()
    ensure_loaded()
    vim.cmd("NvimTreeToggle")
end, { desc = "Toggle NvimTree" })
