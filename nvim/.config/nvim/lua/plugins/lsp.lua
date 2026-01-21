return {
    {
        "saghen/blink.cmp",
        dependencies = {
            { "nvim-mini/mini.snippets" },
        },
        opts = {
            enabled = function()
                return not vim.tbl_contains(
                    { "markdown", "minifiles", "opencode", "opencode_output" },
                    vim.bo.filetype
                )
            end,
            snippets = { preset = "mini_snippets" },
            completion = {
                trigger = {
                    show_on_insert_on_trigger_character = false,
                },
            },
            sources = {
                default = { "lsp", "path", "snippets", "buffer" },
            },
            keymap = {
                preset = "none",
                ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
                ["<C-e>"] = { "hide" },
                ["<C-y>"] = { "select_and_accept" },
                ["<C-n>"] = {
                    function()
                        -- Cycle to next Copilot suggestion if visible
                        local ok, copilot = pcall(require, "copilot.suggestion")
                        if ok and copilot.is_visible() then
                            copilot.next()
                            return true
                        end
                        -- Supermaven: no cycling support, pass through
                        return false
                    end,
                    "select_next",
                    "fallback",
                },
                ["<C-p>"] = {
                    function()
                        -- Cycle to prev Copilot suggestion if visible
                        local ok, copilot = pcall(require, "copilot.suggestion")
                        if ok and copilot.is_visible() then
                            copilot.prev()
                            return true
                        end
                        -- Supermaven: no cycling support, pass through
                        return false
                    end,
                    "select_prev",
                    "fallback",
                },
                ["<C-b>"] = { "scroll_documentation_up", "fallback" },
                ["<C-f>"] = { "scroll_documentation_down", "fallback" },
                ["<CR>"] = { "accept", "fallback" },

                -- Super-Tab: AI completion → blink.cmp → normal Tab
                ["<Tab>"] = {
                    function()
                        -- Check for Copilot suggestion
                        local ok, copilot = pcall(require, "copilot.suggestion")
                        if ok and copilot.is_visible() then
                            copilot.accept()
                            return true
                        end

                        -- Check for Supermaven suggestion
                        local ok2, supermaven = pcall(require, "supermaven-nvim.completion_preview")
                        if ok2 and supermaven.has_suggestion() then
                            supermaven.on_accept_suggestion()
                            return true
                        end

                        -- Not handled, continue to next command
                        return false
                    end,
                    "select_next",
                    "fallback",
                },
                ["<S-Tab>"] = { "select_prev", "fallback" },
            },
        },
        config = function(_, opts)
            require("blink.cmp").setup(opts)

            -- Hide Copilot suggestions when blink.cmp menu is open
            vim.api.nvim_create_autocmd("User", {
                pattern = "BlinkCmpMenuOpen",
                callback = function()
                    vim.b.copilot_suggestion_hidden = true
                end,
            })

            vim.api.nvim_create_autocmd("User", {
                pattern = "BlinkCmpMenuClose",
                callback = function()
                    vim.b.copilot_suggestion_hidden = false
                end,
            })
        end,
    },
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "mason-org/mason.nvim",
            "mason-org/mason-lspconfig.nvim",
            "saghen/blink.cmp",
        },
        opts = {
            diagnostics = {
                virtual_text = {
                    severity = vim.diagnostic.severity.ERROR,
                    spacing = 4,
                    prefix = "",
                },
            },
            setup = {
                autostart = true,
            },
            inlay_hints = { enabled = false },
            autoformat = true,
            format_notify = false,
        },
    },
    { "mason-org/mason.nvim", opts = {} },
    {
        "mason-org/mason-lspconfig.nvim",
        dependencies = { "mason-org/mason.nvim" },
        opts = {
            automatic_enable = true,
            automatic_installation = true,
        },
    },
    {
        "zeioth/garbage-day.nvim",
        dependencies = "neovim/nvim-lspconfig",
        event = "VeryLazy",
    },
    { import = "plugins.lang" },
}
