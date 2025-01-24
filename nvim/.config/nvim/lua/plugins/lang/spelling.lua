return {
	{
		"williamboman/mason.nvim",
		opts = {
			ensure_installed = {
				"codespell",
				"write-good",
			},
		},
	},
	{
		"mfussenegger/nvim-lint",
		opts = {
			linters_by_ft = {
				["*"] = { "codespell", "write_good" },
			},
		},
	},
	{
		"cappyzawa/trim.nvim",
		opts = {},
	},
}
