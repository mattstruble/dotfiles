local py = require("utils.python")

return {
	{
		"rgroli/other.nvim",
		opts = function(_, opts)
			table.insert(opts.mappings, {
				pattern = "(.*)/(.*).py$",
				target = "tests?/.*/test_%2.py",
				context = "tests",
			})
			table.insert(opts.mappings, {
				pattern = "(.*)/(.*).py$",
				target = "tests?/integration/.*/test_%2.py",
				context = "integration",
			})
			table.insert(opts.mappings, {
				pattern = "(.*)/(.*).py$",
				target = "tests?/unit/.*/test_%2.py",
				context = "unit",
			})
		end,
	},
	{
		"williamboman/mason.nvim",
		opts = function(_, opts)
			table.insert(opts.ensure_installed, "black")
			table.insert(opts.ensure_installed, "ruff")
			table.insert(opts.ensure_installed, "debugpy")
			table.insert(opts.ensure_installed, "mypy")
		end,
	},
	{
		"jose-elias-alvarez/null-ls.nvim",
		opts = function(_, opts)
			local nls = require("null-ls")

			table.insert(opts.sources, nls.builtins.formatting.black)
			table.insert(
				opts.sources,
				nls.builtins.formatting.ruff.with({
					extra_args = { "--select", "E,F,I,PL" },
				})
			)
			table.insert(
				opts.sources,
				nls.builtins.diagnostics.mypy.with({
					extra_args = { "--ignore-missing-imports" },
				})
			)
		end,
	},
	{
		"neovim/nvim-lspconfig",
		opts = {
			servers = {
				ruff_lsp = {
					init_options = {
						settings = {
							args = { "--select", "ALL", "--ignore", "E501,ANN101" },
						},
					},
				},
				pyright = {
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
								-- extraPaths = py.pep582(vim.fn.getcwd()),
							},
							-- pythonPath = py.venv(vim.fn.getcwd()),
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
