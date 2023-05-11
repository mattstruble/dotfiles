return {
	{
		"lukas-reineke/indent-blankline.nvim",
		event = {
			"BufReadPost",
			"BufNewFile",
		},
		config = function()
			vim.opt.termguicolors = true
			vim.opt.list = true
			vim.opt.listchars:append("space:⋅")
			vim.opt.listchars:append("eol:↴")

			require("indent_blankline").setup({
				show_end_of_line = true,
				space_char_blankline = " ",
				show_current_context = true,
				show_current_context_start = true,
				filetype_exclude = {
					"help",
					"alpha",
					"dashboard",
					"NvimTree",
					"Trouble",
					"lazy",
					"mason",
				},
			})
		end,
	},
	{
		"lukas-reineke/virt-column.nvim",
		event = {
			"BufReadPre",
			"BufNewFile",
		},
		config = function()
			require("virt-column").setup()
		end,
	},
}
