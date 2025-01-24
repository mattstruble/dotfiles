return {
	{
		"williamboman/mason.nvim",
		opts = {
			ensure_installed = {
				"yamllint",
				"yamlfmt",
			},
		},
	},
	{
		"mfussenegger/nvim-lint",
		opts = {
			linters_by_ft = {
				yaml = { "yamllint" },
			},
		},
	},
	{
		"stevearc/conform.nvim",
		opts = {
			formatters_by_ft = {
				yaml = { "yamlfmt" },
			},
		},
	},
}
