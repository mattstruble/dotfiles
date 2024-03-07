local mode = require("utils.mode")

return {
	{
		"roobert/statusline-action-hints.nvim",
		enabled = false,
		opts = {
			definition_identifier = "gd",
			template = "%s ref:%s",
		},
	},
	{
		"nvim-lualine/lualine.nvim",
		lazy = true,
		event = { "BufReadPre" },
		dependencies = {
			"nvim-tree/nvim-web-devicons",
			"bluz71/vim-nightfly-guicolors",
			"meuter/lualine-so-fancy.nvim",
			"folke/noice.nvim",
			-- "roobert/statusline-action-hints.nvim",
		},
		after = "noice.nvim",
		opts = {
			options = {
				icons_enabled = true,
				component_separators = "|",
				section_separators = { left = "", right = "" },
			},
			sections = {
				lualine_a = {
					{
						"mode",
						fmt = function()
							return mode.isNormal() and ""
								or mode.isInsert() and ""
								or mode.isVisual() and "󰒉"
								or mode.isCommand() and ""
								or mode.isReplace() and ""
								or vim.api.nvim_get_mode().mode == "t" and ""
								or ""
						end,
						separator = { left = "" },
						right_padding = 2,
					},
				},
				lualine_b = {
					{ "fancy_branch" },
					{ "fancy_diff" },
				},
				lualine_c = {},
				lualine_x = {},
				lualine_y = {
					-- { require("statusline-action-hints").statusline },
					{ "fancy_diagnostics" },
					{ "fancy_searchcount" },
					{ "fancy_location" },
				},
				lualine_z = {
					{ "fancy_filetype", separator = { right = "" }, left_padding = 2 },
				},
			},
			extensions = {
				"nvim-tree",
			},
		},
	},
	{
		"rcarriga/nvim-notify",
		lazy = true,
		event = "VeryLazy",
		keys = {
			{
				"<leader>un",
				function()
					require("notify").dismiss({
						silent = true,
						pending = true,
					})
				end,
				desc = "Delete all notifications",
			},
			{
				"<leader>sn",
				"<cmd>Telescope notify<cr>",
				desc = "[S]earch [N]notifications",
			},
		},
		opts = {
			render = "compact",
			timeout = 3000,
			max_height = function()
				return math.floor(vim.o.lines * 0.75)
			end,
			max_width = function()
				return math.floor(vim.o.columns * 0.75)
			end,
		},
	},

	{
		"MunifTanjim/nui.nvim",
		lazy = true,
		event = "VeryLazy",
	},

	{
		"folke/noice.nvim",
		lazy = true,
		event = "VeryLazy",
		dependencies = {
			"MunifTanjim/nui.nvim",
			"rcarriga/nvim-notify",
		},
		config = function()
			require("noice").setup({
				lsp = {
					-- override markdown rendering so that **cmp** and other plugins use **Treesitter**
					override = {
						["vim.lsp.util.convert_input_to_markdown_lines"] = true,
						["vim.lsp.util.stylize_markdown"] = true,
						["cmp.entry.get_documentation"] = true,
					},
					signature = { enabled = true },
					hover = { enabled = true },
				},
				presets = {
					inc_rename = true,
					bottom_search = true,
					command_palette = true,
					long_message_to_split = true,
					lsp_doc_border = true,
				},
			})
		end,
	},
}
