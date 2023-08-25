--------------------------
-- TREESITTER
--------------------------

return {
	{
		{
			"https://gitlab.com/HiPhish/rainbow-delimiters.nvim.git",
			lazy = true,
			event = { "BufReadPost", "BufNewFile" },
		},
		{
			"nvim-treesitter/nvim-treesitter-context",
			lazy = true,
			event = { "BufReadPost", "BufNewFile" },
		},
		{
			"nvim-treesitter/nvim-treesitter",
			opts = {
				sync_install = false,
				auto_install = true,
				highlight = {
					enable = true,
					additional_vim_regex_highlighting = false,
				},
				autopairs = { enable = true },
				indent = { enable = true },
				autotag = { enable = true },
				ensure_installed = {
					"bash",
					"c",
					"html",
					"javascript",
					"jsdoc",
					"json",
					"lua",
					"luadoc",
					"luap",
					"markdown",
					"markdown_inline",
					"python",
					"query",
					"regex",
					"tsx",
					"typescript",
					"vim",
					"vimdoc",
					"yaml",
				},
				incremental_selection = {
					enable = true,
					keymaps = {
						init_selection = "<C-space>",
						node_incremental = "<C-space>",
						scope_incremental = false,
						node_decremental = "<bs>",
					},
				},
			},
		},
	},
}
