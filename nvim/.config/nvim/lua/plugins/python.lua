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
			},
		},
	},
}
