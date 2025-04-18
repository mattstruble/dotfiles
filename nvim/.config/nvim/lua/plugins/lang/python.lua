local py = require("utils.python")

return {
    {
        "williamboman/mason.nvim",
        opts = {
            ensure_installed = {
                "ruff",
                "debugpy",
            },
        },
    },
    {
        "williamboman/mason-lspconfig.nvim",
        opts = {
            ensure_installed = {
                "ruff",
                "pyright",
            },
        },
    },
    {
        "mfussenegger/nvim-lint",
        opts = {
            linters_by_ft = {
                python = { "ruff" },
            },
        },
    },
    {
        "stevearc/conform.nvim",
        opts = {
            formatters_by_ft = {
                python = { "ruff_fix", "ruff_format", "ruff_organize_imports" },
            },
        },
    },
    {
        "nvim-neotest/neotest",
        dependencies = { "nvim-neotest/neotest-python" },
        opts = {
            adapters = {
                ["neotest-python"] = {
                    runner = "pytest",
                    python = py.venv(vim.fn.getcwd()),
                },
            },
        },
    },
    {
        "mfussenegger/nvim-dap",
        dependencies = { "mfussenegger/nvim-dap-python" },
        config = function()
            local path = require("mason-registry")
                .get_package("debugpy")
                :get_install_path()
            require("dap-python").setup(path .. "/venv/bin/python")
            require("dap-python").resolve_python = function()
                py.env(vim.fn.getcwd())
                return py.venv(vim.fn.getcwd())
            end
        end,
    },
}
