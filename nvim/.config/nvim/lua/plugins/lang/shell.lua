return {
	{
		"williamboman/mason.nvim",
		opts = {
			"shfmt",
			"bash-language-server",
		},
	},
	{
		"mfussenegger/nvim-lint",
		opts = {
			linters_by_ft = {
				sh = { "shellcheck" },
			},
		},
	},
	{
		"stevearc/conform.nvim",
		opts = {
			formatters_by_ft = {
				sh = { "shfmt", "shellharden" },
			},
		},
	},
}
