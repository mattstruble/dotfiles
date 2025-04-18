return {
	{
		"axkirillov/hbac.nvim",
		lazy = true,
		event = "BufAdd",
		dependencies = {
			-- these are optional, add them, if you want the telescope module
			"nvim-tree/nvim-web-devicons",
		},
		config = function()
			require("hbac").setup()
		end,
	},
	{
		"sQVe/bufignore.nvim",
		lazy = true,
		event = "BufAdd",
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {
			auto_start = true,
			ignore_sources = {
				git = true,
				patterns = { "%.git/", "%.venv/", "%.direnv/" },
				symlink = true,
			},
		},
	},
}
