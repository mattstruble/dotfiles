vim.pack.add({ "https://github.com/folke/snacks.nvim" })
require("snacks").setup({
    animate = { enabled = false },
    bigfile = { enabled = true },
    explorer = { replace_netrw = true },
    quickfile = { enabled = true },
    notifier = { enabled = true, timeout = 3000 },
    picker = {
        matcher = { frecency = true },
        ui_select = true,
    },
    input = { enabled = true },
    image = { enabled = true },
    indent = { enabled = true },
    words = { enabled = true },
    lazygit = { enabled = true },
    scroll = { enabled = false },
    statuscolumn = { enabled = false },
    styles = {
        notifications = { wo = { wrap = true } },
    },
    terminal = {},
    zen = { enabled = true },
    dashboard = {
        enabled = false,
        formats = {
            key = function(item)
                return {
                    { "[", hl = "special" },
                    { item.key, hl = "key" },
                    { "]", hl = "special" },
                }
            end,
        },
        sections = {
            {
                section = "terminal",
                cmd = "fortune -s | cowsay",
                hl = "header",
                padding = 1,
                indent = 8,
            },
            {
                title = "MRU ",
                file = vim.fn.fnamemodify(".", ":~"),
                padding = 1,
            },
            {
                section = "recent_files",
                cwd = true,
                limit = 8,
                padding = 1,
            },
        },
    },
})

local map = vim.keymap.set
map("n", "<leader>S", function() Snacks.scratch.select() end, { desc = "Select Scratch Buffer" })
map("n", "<leader>n", function() Snacks.notifier.show_history() end, { desc = "Notification History" })
map("n", "<leader>un", function() Snacks.notifier.hide() end, { desc = "Dismiss All Notifications" })
map("n", "<leader>bd", function() Snacks.bufdelete() end, { desc = "Delete Buffer" })
map("n", "<leader>gg", function() Snacks.lazygit() end, { desc = "Lazygit" })
map("n", "<leader>gb", function() Snacks.git.blame_line() end, { desc = "Git Blame Line" })
map("n", "<leader>gB", function() Snacks.gitbrowse() end, { desc = "Git Browse" })
map({ "n", "v" }, "<leader>gY", function()
    Snacks.gitbrowse({
        open = function(url)
            vim.fn.setreg("+", url)
            vim.notify("Git URL copied: " .. url, vim.log.levels.INFO)
        end,
    })
end, { desc = "Git Browse (copy URL)" })
map("n", "<leader>gf", function() Snacks.lazygit.log_file() end, { desc = "Lazygit Current File History" })
map("n", "<leader>gl", function() Snacks.lazygit.log() end, { desc = "Lazygit Log (cwd)" })
map("n", "<leader>cR", function() Snacks.rename.rename_file() end, { desc = "Rename File" })
map("n", "<leader>zz", function() Snacks.zen.zen() end, { desc = "Zen mode" })
