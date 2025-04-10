return {
    {
        "williamboman/mason.nvim",
        opts = {
            ensure_installed = {
                "rust-analyzer",
                "codelldb",
                "rustfmt",
            },
        },
    },
    {
        "williamboman/mason-lspconfig.nvim",
        opts = {
            ensure_installed = {
                "rust_analyzer",
            },
        },
    },
    {
        "nvim-treesitter/nvim-treesitter",
        opts = {
            ensure_installed = { "rust" },
        },
    },
    {
        "stevearc/conform.nvim",
        opts = {
            formatters_by_ft = {
                rust = { "rustfmt", lsp_format = "fallback" },
            },
        },
    },
    {
        "mfussenegger/nvim-lint",
        opts = {
            linters = {
                cargo = {
                    cmd = "cargo",
                    stdin = false,
                    args = { "check" },
                    stream = "both",
                    ignore_exitcode = false,
                    env = nil,
                },
            },
            linters_by_ft = {
                rust = { "cargo" },
            },
        },
    },
    {
        "neovim/nvim-lspconfig",
        opts = {
            servers = {
                rust_analyzer = {
                    ["rust-analyzer"] = {
                        diagnostics = {
                            enable = true,
                        },
                    },
                },
            },
        },
    },
    {
        "simrat39/rust-tools.nvim",
        ft = "rust",
        config = function()
            local rt = require("rust-tools")
            rt.setup({
                on_attach = function(_, bufnr)
                    vim.keymap.set(
                        "n",
                        "<C-space>",
                        rt.hover_actions.hover_actions,
                        { buffer = bufnr }
                    )
                    vim.keymap.set(
                        "n",
                        "<leader>a",
                        rt.code_action_group.code_action_group,
                        { buffer = bufnr }
                    )
                end,
            })
        end,
    },
    {
        "mfussenegger/nvim-dap",
        opts = function(_, opts)
            if opts.configurations == nil then opts.configurations = {} end
            opts.configurations.rust = {
                name = "Launch file",
                type = "codelldb",
                request = "launch",
                program = function()
                    return vim.fn.input(
                        "Path to executable: ",
                        vim.fn.getcwd() .. "/",
                        "file"
                    )
                end,
                cwd = "${workspaceFolder}",
                stopOnEntry = false,
            }
        end,
    },
}
