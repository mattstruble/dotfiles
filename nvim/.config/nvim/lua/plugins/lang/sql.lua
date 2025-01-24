return {
	{
		"williamboman/mason.nvim",
		opts = {
			ensure_installed = {
				"sqlfluff",
				"sqlls",
			},
		},
	},
	{
		"mfussenegger/nvim-lint",
		opts = {
			linters_by_ft = {
				sql = { "sqruff" },
			},
		},
	},
	{
		"stevearc/conform.nvim",
		opts = {
			formatters_by_ft = {
				sql = { "sqruff" },
			},
		},
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
