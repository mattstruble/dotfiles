return {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts_extend = { "spec" },
    opts = {
        preset = "helix",
        spec = {
            {
                mode = { "n", "x" },
                { "<leader><tab>", group = "tabs" },
                { "<leader>a", group = "autopairs" },
                { "<leader>c", group = "code" },
                { "<leader>cg", group = "generate" },
                { "<leader>f", group = "file/find" },
                { "<leader>g", group = "git" },
                { "<leader>gh", group = "hunks" },
                { "<leader>m", group = "markdown" },
                { "<leader>q", group = "quit/session" },
                { "<leader>s", group = "search" },
                { "<leader>u", group = "ui" },
                { "<leader>v", group = "view" },
                { "<leader>x", group = "diagnostics/quickfix" },
                { "<leader>z", group = "zen" },
                { "[", group = "prev" },
                { "]", group = "next" },
                { "g", group = "goto" },
                { "g>", group = "swap next" },
                { "g<", group = "swap prev" },
                { "gs", group = "surround" },
                { "z", group = "fold" },
                {
                    "<leader>b",
                    group = "buffer",
                    expand = function()
                        return require("which-key.extras").expand.buf()
                    end,
                },
                {
                    "<leader>w",
                    group = "windows",
                    proxy = "<c-w>",
                    expand = function()
                        return require("which-key.extras").expand.win()
                    end,
                },
                { "gx", desc = "Open with system app" },
            },
        },
    },
    keys = {
        {
            "<c-w><space>",
            function()
                require("which-key").show({ keys = "<c-w>", loop = true })
            end,
            desc = "Window Hydra Mode (which-key)",
        },
    },
}
