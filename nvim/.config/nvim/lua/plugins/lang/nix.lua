return {
	{
		"williamboman/mason.nvim",
		opts = function(_, opts)
			table.insert(opts.ensure_installed, "nixpkgs-fmt")
		end,
	},
	{
		"nvimtools/none-ls.nvim",
		opts = function(_, opts)
			local nls = require("null-ls")

			table.insert(opts.sources, nls.builtins.formatting.nixfmt)
			table.insert(opts.sources, nls.builtins.formatting.nixpkgs_fmt)
		end,
	},
}
