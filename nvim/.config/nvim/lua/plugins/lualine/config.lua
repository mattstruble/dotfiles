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
			left = "",
			right = "",
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
		lualine_b = {},
		lualine_c = {
			{
				"branch",
				icon = " ",
			},
			{
				"diff",
				symbols = {
					added = " ",
					modified = " ",
					removed = " ",
				},
			},
			{
				"diagnostics",
				update_in_insert = true,
			},
			components.lsp,
		},
		lualine_x = {
			-- components.location,
			-- components.spaces,
			"encoding",
			"fileformat",
			"filetype",
		},
		lualine_y = {},
		lualine_z = {
			{ "progress", icon = "" },
			components.location,
		},
	},
	extensions = {
		"nvim-tree",
	},
})
