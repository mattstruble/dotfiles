vim.pack.add({ "https://github.com/stevearc/conform.nvim" })

require("conform").setup({
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
        python = { "ruff_format" },
        fennel = { "fnlfmt" },
        gdscript = { "gdscript-formatter" },
        tex = { "tex-fmt" },
        markdown = { "mdformat" },
        nix = { "nixfmt" },
        rust = { "rustfmt", lsp_format = "fallback" },
        sh = { "shfmt", "shellharden" },
        bash = { "shfmt", "shellharden" },
        sql = { "sqruff" },
        terraform = { "terraform_fmt", "tofu_fmt", stop_after_first = true },
        hcl = { "terraform_fmt", "tofu_fmt", stop_after_first = true },
        yaml = { "yamlfmt", "trim_newlines" },
    },
    formatters = {
        injected = { options = { ignore_errors = true } },
    },
})

vim.keymap.set({ "n", "x" }, "<leader>cf", function()
    require("conform").format()
end, { desc = "Format" })

vim.keymap.set({ "n", "x" }, "<leader>cF", function()
    require("conform").format({ formatters = { "injected" }, timeout_ms = 3000 })
end, { desc = "Format Injected Langs" })
