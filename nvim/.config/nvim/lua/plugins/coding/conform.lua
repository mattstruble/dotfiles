return {
    "stevearc/conform.nvim",
    lazy = true,
    cmd = "ConformInfo",
    event = { "BufWritePre" },
    keys = {
        {
            "<leader>cf",
            function()
                require("conform").format()
            end,
            mode = { "n", "x" },
            desc = "Format",
        },
        {
            "<leader>cF",
            function()
                require("conform").format({ formatters = { "injected" }, timeout_ms = 3000 })
            end,
            mode = { "n", "x" },
            desc = "Format Injected Langs",
        },
    },
    opts = {
        format_on_save = {
            timeout_ms = 3000,
            lsp_format = "fallback",
        },
        default_format_opts = {
            timeout_ms = 3000,
            async = false,
            quiet = false,
            lsp_format = "fallback",
        },
        formatters_by_ft = {
            lua = { "stylua" },
        },
        formatters = {
            injected = { options = { ignore_errors = true } },
        },
    },
}
