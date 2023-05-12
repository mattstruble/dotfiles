return {
	{
		"bluz71/vim-nightfly-colors",
		name = "nightfly",
		lazy = false,
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
		enabled = false,
		config = function()
			require("catppuccin").setup({
				flavour = "mocha",
				background = {
					light = "latte",
					dark = "mocha",
				},
				transparent_background = false,
				show_end_of_buffer = true,
				term_colors = true,
				dim_inactive = {
					enabled = false,
				},
				no_italic = false,
				no_bold = false,
				styles = {
					comments = { "italic" },
					properties = {},
					functions = { "bold" },
					keywords = {},
					operators = { "bold" },
					conditionals = { "bold" },
					loops = { "bold" },
					booleans = { "bold" },
					numbers = {},
					types = {},
					strings = {},
					variables = {},
				},
				custom_highlights = {},
				integrations = {
					native_lsp = {
						enabled = true,
						virtual_text = {
							errors = {},
							hints = {},
							warnings = {},
							information = {},
						},
						underlines = {
							errors = { "undercurl" },
							hints = { "undercurl" },
							warnings = { "undercurl" },
							information = { "undercurl" },
						},
					},
					indent_blankline = { enabled = true, colored_indent_levels = true },
					nvimtree = true,
					which_key = true,
					cmp = true,
					gitsigns = true,
					nvimtree = true,
					telescope = true,
					notify = true,
				},
			})
			vim.cmd.colorscheme("catppuccin")
		end,
	},
}
