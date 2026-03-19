vim.lsp.enable("marksman")

return {
    {
        "mfussenegger/nvim-lint",
        opts = {
            linters_by_ft = {
                markdown = { "markdownlint" },
            },
        },
    },
    {
        "stevearc/conform.nvim",
        opts = {
            formatters_by_ft = {
                markdown = { "mdformat" },
            },
        },
    },
    {
        "mzlogin/vim-markdown-toc",
        ft = "markdown",
        lazy = true,
        keys = {
            {
                "<leader>mtoc",
                "<cmd>GenTocMarked<cr>",
                desc = "Generate Markdown TOC",
            },
        },
    },
}
