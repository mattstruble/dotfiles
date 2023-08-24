return {
	{
		"williamboman/mason.nvim",
		opts = function(_, opts)
			table.insert(opts.ensure_installed, "codespell")
		end,
	},
	{
		"jose-elias-alvarez/null-ls.nvim",
		opts = function(_, opts)
			local nls = require("null-ls")

			table.insert(opts.sources, nls.builtins.formatting.codespell)
			table.insert(opts.sources, nls.builtins.formatting.trim_whitespace)
			table.insert(opts.sources, nls.builtins.diagnostics.codespell)
			table.insert(opts.sources, nls.builtins.diagnostics.write_good)
		end,
	},
}