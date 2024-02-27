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
		event = { "BufReadPost", "BufNewFile" },
		dependencies = {
			"nvim-tree/nvim-web-devicons",
			"bluz71/vim-nightfly-guicolors",
			"meuter/lualine-so-fancy.nvim",
			-- "roobert/statusline-action-hints.nvim",
		},
		config = function()
			require("plugins.lualine.config")
		end,
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
				"<cmd>Telescope notify",
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
