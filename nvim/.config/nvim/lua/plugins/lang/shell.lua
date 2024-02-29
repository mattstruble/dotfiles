return {
	{
		"williamboman/mason.nvim",
		opts = function(_, opts)
			table.insert(opts.ensure_installed, "shfmt")
			table.insert(opts.ensure_installed, "bash-language-server")
		end,
	},
	{
		"nvimtools/none-ls.nvim",
		opts = function(_, opts)
			local nls = require("null-ls")

			table.insert(opts.sources, nls.builtins.formatting.shellharden)
			table.insert(opts.sources, nls.builtins.formatting.beautysh)
			table.insert(opts.sources, nls.builtins.diagnostics.shellcheck)
		end,
	},
}
