local lualine = require("lualine")
local components = require("plugins.lualine.components")

lualine.setup({
	icons_enabled = true,
	options = {
		component_separators = {
			left = "|",
			right = "|",
		},
		section_separators = {
			left = "",
			right = "",
		},
	},
	sections = {
		lualine_a = {
			{
				"mode",
				fmt = function()
					return "󰀘"
				end,
			},
		},
		lualine_b = {
			{ "fancy_branch" },
			{ "fancy_diff" },
		},
		lualine_c = {},
		lualine_x = {
			{ "fancy_diagnostics" },
			{ "fancy_searchcount" },
			{ "fancy_location" },
		},
		lualine_y = {
			{ "fancy_filetype", ts_icon = "" },
		},
		lualine_z = {
			components.lsp,
		},
	},
	extensions = {
		"nvim-tree",
	},
})
