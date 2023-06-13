return {
	{
		"axkirillov/hbac.nvim",
		dependencies = {
			-- these are optional, add them, if you want the telescope module
			"nvim-telescope/telescope.nvim",
			"nvim-lua/plenary.nvim",
			"nvim-tree/nvim-web-devicons",
		},
		config = function()
			require("hbac").setup()
		end,
	},
	{
		"sQVe/bufignore.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {
			auto_start = true,
			ignore_sources = {
				git = true,
				patterns = { "%.git/" },
				symlink = true,
			},
		},
	},
}
