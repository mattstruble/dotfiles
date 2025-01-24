local py = require("utils.python")

return {
	{
		"williamboman/mason.nvim",
		opts = {
			ensure_installed = {
				"ruff",
				"mypy",
			},
		},
	},
	{
		"mfussenegger/nvim-lint",
		opts = {
			linters_by_ft = {
				python = { "ruff", "pydocstyle" },
			},
		},
	},
	{
		"stevearc/conform.nvim",
		opts = {
			formatters_by_ft = {
				python = { "ruff_fix", "ruff_format" },
			},
		},
	},
	{
		"neovim/nvim-lspconfig",
		opts = {
			servers = {
				pyright = {
					setup = { autostart = false },
					capabilities = (function()
						local capabilities = vim.lsp.protocol.make_client_capabilities()
						capabilities.textDocument.publishDiagnostics.tagSupport.valueSet = { 2 }
						return capabilities
					end)(),
					settings = {
						python = {
							analysis = {
								typeCheckingMode = "basic",
								useLibraryCodeForTypes = true,
								completeFunctionParens = true,
								extraPaths = py.pep582(vim.fn.getcwd()),
							},
							pythonPath = py.venv(vim.fn.getcwd()),
							venvPath = py.venv(vim.fn.getcwd()),
						},
					},
					on_new_config = function(new_config, new_root_dir)
						py.env(new_root_dir)
						new_config.settings.python.venvPath = py.venv(new_root_dir)
						-- new_config.settings.python.pythonPath = py.venv(new_root_dir)
						-- new_config.settings.python.analysis.extraPaths = { py.pep582(new_root_dir) }
					end,
				},
			},
		},
	},
	{
		"nvim-neotest/neotest",
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
		config = function()
			local path = require("mason-registry").get_package("debugpy"):get_install_path()
			require("dap-python").setup(path .. "/venv/bin/python")
			require("dap-python").resolve_python = function()
				py.env(vim.fn.getcwd())
				return py.venv(vim.fn.getcwd())
			end
		end,
	},
}
