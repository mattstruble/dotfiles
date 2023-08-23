return {
	{
		"williamboman/mason.nvim",
		opts = function(_, opts)
			table.insert(opts.ensure_installed, "ansiblelint")
			table.insert(opts.ensure_installed, "ansible-language-server")
		end,
	},
	{
		"jose-elias-alvarez/null-ls.nvim",
		opts = function(_, opts)
			local nls = require("null-ls")

			table.insert(opts.sources, nls.builtins.diagnostics.ansiblelint)
		end,
	},
}
