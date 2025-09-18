--------------------------
-- MARKDOWN PREVIEW
--------------------------

return {
    {
        "mason-org/mason.nvim",
        opts = {
            ensure_installed = {
                "markdownlint",
                "marksman",
                "markdownfmt",
            },
        },
    },
    {
        "mason-org/mason-lspconfig.nvim",
        opts = {
            ensure_installed = {
                "marksman",
            },
        },
    },
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
                markdown = { "markdownfmt" },
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
    {
        "iamcco/markdown-preview.nvim",
        lazy = true,
        enbaled = false,
        cmd = {
            "MarkdownPreview",
            "MarkdownPreviewStop",
            "MarkdownPreviewToggle",
        },
        ft = "markdown",
        build = "cd app && npm install",
        config = function()
            vim.g.mkdp_page_title = "${name} - Preview"
            vim.g.mkdp_echo_preview_url = 1
            vim.g.mkdp_filetypes = { "markdown" }
        end,
        -- stylua: ignore
        keys = {
            { "<leader>mp", "<cmd>MarkdownPreview<cr>", desc = "Markdown Preview"},
            { "<leader>mps", "<cmd>MarkdownPreviewStop<cr>", desc = "Markdown Preview Stop"},
            { "<leader>mpt", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown Preview Toggle"},
        },
    },
    {
        "plasticboy/vim-markdown",
        dependencies = "godlygeek/tabular",
        lazy = true,
        enabled = false,
        ft = "markdown",
        config = function()
            vim.g.vim_markdown_folding_disabled = 1
            vim.g.vim_markdown_toc_autofit = 1
            vim.g.vim_markdown_follow_anchor = 1
            vim.g.vim_markdown_conceal = 1
            vim.g.vim_markdown_conceal_code_blocks = 1
            vim.g.vim_markdown_math = 1
            vim.g.vim_markdown_frontmatter = 1
            vim.g.vim_markdown_strikethrough = 1
            vim.g.vim_markdown_new_list_item_indent = 4
            vim.g.vim_markdown_edit_url_in = "tab"

            vim.o.conceallevel = 3
            vim.g.tex_conceal = ""
        end,
    },
    {
        "lukas-reineke/headlines.nvim",
        dependencies = "nvim-treesitter/nvim-treesitter",
        enabled = false,
        lazy = true,
        ft = "markdown",
        config = function()
            require("headlines").setup({
                markdown = {
                    query = vim.treesitter.query.parse(
                        "markdown",
                        [[
                            (atx_heading [
                                (atx_h1_marker)
                                (atx_h2_marker)
                                (atx_h3_marker)
                                (atx_h4_marker)
                                (atx_h5_marker)
                                (atx_h6_marker)
                            ] @headline)

                            (thematic_break) @dash

                            (fenced_code_block) @codeblock

                            (block_quote_marker) @quote
                            (block_quote (paragraph (inline (block_continuation) @quote)))
                        ]]
                    ),
                    headline_highlights = {
                        "Headline1",
                        "Headline2",
                        "Headline3",
                        "Headline4",
                        "Headline5",
                        "Headline6",
                    },
                    -- dash_highlight = "Dash",
                    -- dash_string = "-",
                    -- quote_highlight = "Quote",
                    -- quote_string = "┃",
                    fat_headlines = true,
                    fat_headline_upper_string = "",
                    fat_headline_lower_string = "",
                },
            })

            vim.api.nvim_set_hl(
                0,
                "Headline1",
                { fg = "#cb7676", bg = "#402626", italic = false }
            )
            vim.api.nvim_set_hl(
                0,
                "Headline2",
                { fg = "#c99076", bg = "#66493c", italic = false }
            )
            vim.api.nvim_set_hl(
                0,
                "Headline3",
                { fg = "#80a665", bg = "#3d4f2f", italic = false }
            )
            vim.api.nvim_set_hl(
                0,
                "Headline4",
                { fg = "#4c9a91", bg = "#224541", italic = false }
            )
            vim.api.nvim_set_hl(
                0,
                "Headline5",
                { fg = "#6893bf", bg = "#2b3d4f", italic = false }
            )
            vim.api.nvim_set_hl(
                0,
                "Headline6",
                { fg = "#d3869b", bg = "#6b454f", italic = false }
            )
        end,
    },
}
