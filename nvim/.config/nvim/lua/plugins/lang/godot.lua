return {
	{
		"williamboman/mason.nvim",
		opts = {
			"gdtoolkit",
		},
	},
	{
		"mfussenegger/nvim-lint",
		opts = {
			linters_by_ft = {
				gd = { "gdlint" },
			},
		},
	},
	{
		"stevearc/conform.nvim",
		opts = {
			formatters_by_ft = {
				gd = { "gdformat" },
			},
		},
	},
}
