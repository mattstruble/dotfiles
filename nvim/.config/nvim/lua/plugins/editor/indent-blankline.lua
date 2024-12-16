local highlight = {
	"RainbowRed",
	"RainbowYellow",
	"RainbowBlue",
	"RainbowOrange",
	"RainbowGreen",
	"RainbowViolet",
	"RainbowCyan",
}

return {
	{
		"lukas-reineke/indent-blankline.nvim",
		enabled = false,
		lazy = true,
		main = "ibl",
		dependencies = { "HiPhish/rainbow-delimiters.nvim" },
		event = {
			"BufReadPost",
			"BufNewFile",
		},
		config = function()
			vim.opt.termguicolors = true
			vim.opt.list = true
			vim.opt.listchars:append("space:⋅")
			vim.opt.listchars:append("eol:󰌑")

			local hooks = require("ibl.hooks")
			-- create the highlight groups in the highlight setup hook, so they are reset
			-- every time the colorscheme changes
			hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
				vim.api.nvim_set_hl(0, "RainbowRed", { fg = "#E06C75" })
				vim.api.nvim_set_hl(0, "RainbowYellow", { fg = "#E5C07B" })
				vim.api.nvim_set_hl(0, "RainbowBlue", { fg = "#61AFEF" })
				vim.api.nvim_set_hl(0, "RainbowOrange", { fg = "#D19A66" })
				vim.api.nvim_set_hl(0, "RainbowGreen", { fg = "#98C379" })
				vim.api.nvim_set_hl(0, "RainbowViolet", { fg = "#C678DD" })
				vim.api.nvim_set_hl(0, "RainbowCyan", { fg = "#56B6C2" })
			end)

			vim.g.rainbow_delimiters = { highlight = highlight }

			require("ibl").setup({
				-- show_end_of_line = true,
				-- space_char_blankline = " ",
				-- show_current_context = true,
				-- show_current_context_start = true,
				scope = { highlight = highlight },
				indent = {
					char = "|",
				},
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

			hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
		end,
	},
	{
		"lukas-reineke/virt-column.nvim",
		enabled = false,

		lazy = true,
		enabled = false,
		event = {
			"BufReadPre",
			"BufNewFile",
		},
	},
}
