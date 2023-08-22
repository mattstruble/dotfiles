return {
	{
		"williamboman/mason.nvim",
		opts = function(_, opts)
			table.insert(opts.ensure_installed, "black")
			table.insert(opts.ensure_installed, "ruff")
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
							args = { "--select", "ALL", "--ignore", "E501" },
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
							},
						},
					},
					on_new_config = function(new_config, new_root_dir)
						local py = require("utils.python")
						py.env(new_root_dir)
						new_config.settings.python.pythonPath = vim.fn.exepath("python")
						new_config.settings.python.analysis.extraPaths = { py.pep582(new_root_dir) }
					end,
				},
			},
		},
	},
}
