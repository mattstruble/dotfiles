local lualine = require("lualine")
local components = require("plugins.lualine.components")
local nightfly = require("lualine.themes.nightfly")
local new_colors = {
	blue = "#65D1FF",
	green = "#3EFFDC",
	violet = "#FF61EF",
	yellow = "#FFDA7B",
	black = "#000000",
}

nightfly.normal.a.bg = new_colors.blue
nightfly.insert.a.bg = new_colors.green
nightfly.visual.a.bg = new_colors.violet
nightfly.command = {
	a = {
		gui = "bold",
		bg = new_colors.yellow,
		fg = new_colors.black,
	},
}

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
		theme = nightfly,
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
