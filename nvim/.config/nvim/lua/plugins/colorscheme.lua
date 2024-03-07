return {
	{
		"bluz71/vim-nightfly-colors",
		name = "nightfly",
		lazy = false,
		enabled = false,
		priority = 1000,
		config = function()
			vim.cmd.colorscheme("nightfly")
		end,
	},
	{
		"catppuccin/nvim",
		name = "catppuccin",
		priority = 1000,
		lazy = false,
		enabled = true,
		config = function()
			vim.cmd.colorscheme("catppuccin-mocha")
		end,
	},
}
