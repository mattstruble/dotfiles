return {
	{
		"lukas-reineke/indent-blankline.nvim",
		lazy = true,
		main = "ibl",
		event = {
			"BufReadPost",
			"BufNewFile",
		},
		config = function()
			vim.opt.termguicolors = true
			vim.opt.list = true
			vim.opt.listchars:append("space:⋅")
			vim.opt.listchars:append("eol:↴")

			require("ibl").setup({
				-- show_end_of_line = true,
				-- space_char_blankline = " ",
				-- show_current_context = true,
				-- show_current_context_start = true,
				exclude = {
					filetypes = {
						"help",
						"alpha",
						"dashboard",
						"NvimTree",
						"Trouble",
						"lazy",
						"mason",
						"gitcommit",
						"TelescopePrompt",
						"TelescopeResults",
						"toggleterm",
						"checkhealth",
						"man",
						"lspinfo",
					},
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
