vim.schedule(function()
    vim.pack.add({ "https://github.com/nvim-mini/mini.pairs" })
    require("mini.pairs").setup({
        modes = { insert = true, command = false, terminal = false },
        mappings = {
            [")"] = { action = "close", pair = "()", neigh_pattern = "[^\\]." },
            ["]"] = { action = "close", pair = "[]", neigh_pattern = "[^\\]." },
            ["}"] = { action = "close", pair = "{}", neigh_pattern = "[^\\]." },
            ["["] = { action = "open", pair = "[]", neigh_pattern = ".[%s%z%)}%]]", register = { cr = true } },
            ["{"] = { action = "open", pair = "{}", neigh_pattern = ".[%s%z%)}%]]", register = { cr = true } },
            ["("] = { action = "open", pair = "()", neigh_pattern = ".[%s%z%)]", register = { cr = true } },
            ['"'] = { action = "closeopen", pair = '""', neigh_pattern = "[^%w\\][^%w]", register = { cr = false } },
            ["'"] = { action = "closeopen", pair = "''", neigh_pattern = "[^%w\\][^%w]", register = { cr = false } },
            ["`"] = { action = "closeopen", pair = "``", neigh_pattern = "[^%w\\][^%w]", register = { cr = false } },
        },
        skip_next = [=[[%w%%%'%[%"%.%`%$]]=],
        skip_ts = { "string" },
        skip_unbalanced = true,
        markdown = true,
    })

    vim.keymap.set("n", "<leader>ap", function()
        vim.b.minipairs_disable = not vim.b.minipairs_disable
        local state = vim.b.minipairs_disable and "disabled" or "enabled"
        vim.notify("mini-pairs " .. state)
    end, { desc = "Toggle mini pairs" })
end)
