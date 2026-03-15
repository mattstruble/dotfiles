return {
	{
		"mason-org/mason.nvim",
		opts = {
			ensure_installed = {
				"actionlint",
				"gitlint",
			},
		},
	},
	{
		"mfussenegger/nvim-lint",
		opts = {
			linters_by_ft = {
				yaml = { "actionlint" },
				git = { "gitlint" },
			},
		},
	},
	{
		"wintermute-cell/gitignore.nvim",
		enabled = false,
		lazy = true,
		dependencies = {
			"nvim-telescope/telescope.nvim",
		},
		keys = {
			{ "<leader>gi", "<cmd>Gitignore<CR>", desc = "Generate gitignore" },
		},
	},
	{
		"pwntester/octo.nvim",
		lazy = true,
		cmd = "Octo",
		enabled = false,
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope.nvim",
			"nvim-tree/nvim-web-devicons",
		},
		config = function()
			require("octo").setup()
		end,
	},

	{
		"lewis6991/gitsigns.nvim",
		lazy = true,
		event = "VeryLazy",
		config = function()
			require("gitsigns").setup()
		end,
	},
}
