return {
	{
		"williamboman/mason.nvim",
		opts = function(_, opts)
			table.insert(opts.ensure_installed, "sqlfluff")
			table.insert(opts.ensure_installed, "sqlls")
		end,
	},
	{
		"nvimtools/none-ls.nvim",
		opts = function(_, opts)
			local nls = require("null-ls")

			table.insert(
				opts.sources,
				nls.builtins.formatting.sqlfluff.with({
					extra_args = { "--dialect", "snowflake", "--disable-progress-bar", "--quiet" },
				})
			)
			table.insert(
				opts.sources,
				nls.builtins.diagnostics.sqlfluff.with({
					extra_args = { "--dialect", "snowflake", "--show-lint-violations" },
				})
			)
		end,
	},
	{
		"kristijanhusak/vim-dadbod-ui",
		dependencies = {
			"tpope/vim-dadbod",
			"kristijanhusak/vim-dadbod-completion",
		},
		lazy = true,
		keys = {
			{
				"<leader>vb",
				"<cmd>DBUIToggle<cr>",
				desc = "View dadbod",
			},
		},
	},
}
