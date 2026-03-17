return {
    "dmtrKovalenko/fff.nvim",
    build = function()
        require("fff.download").download_or_build_binary()
    end,
    lazy = false,
    keys = {
        { "<leader>ff", function() require("fff").find_files() end, desc = "Find Files" },
        { "<leader>fg", function() require("fff").live_grep() end, desc = "Live Grep" },
        { "<leader>fr", function() require("fff").find_files() end, desc = "Recent Files" },
        {
            "<leader>fc",
            function() require("fff").find_files_in_dir(vim.fn.stdpath("config")) end,
            desc = "Find Config File",
        },
        { "<leader>sg", function() require("fff").live_grep() end, desc = "Grep" },
        {
            "<leader>sw",
            function() require("fff").live_grep({ query = vim.fn.expand("<cword>") }) end,
            desc = "Grep Word (cword)",
        },
        {
            "<leader>sW",
            function() require("fff").live_grep({ query = vim.fn.expand("<cWORD>") }) end,
            desc = "Grep Word (cWORD)",
        },
        {
            "<leader>sw",
            function()
                vim.cmd('noau normal! "vy')
                require("fff").live_grep({ query = vim.fn.getreg("v") })
            end,
            mode = "v",
            desc = "Grep Selection",
        },
    },
}
