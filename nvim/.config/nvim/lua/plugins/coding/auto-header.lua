return {
	"VincentBerthier/auto-header.nvim",
	lazy = true,
	keys = { { "<leader>ah", desc = "Auto Header" } },
	config = function()
		require("auto-header").setup({
			templates = {
				{
					language = "*",
					prefix = "auto",
					after = { "" },
					template = {
						require("auto-header").licenses.MIT,
					},
				},
				{
					language = "python",
					prefix = "auto",
					before = { "# -*- coding: utf-8 -*-" },
					block_length = 0,
					after = { "" },
					track_change = {
						"Copyright ",
					},
					template = {
						"#project_name",
						"#author_mail",
						"#file_relative_path",
						require("auto-header").licenses.MIT,
					},
				},
				{
					language = "shellscript",
					before = { "#!/usr/bin/env bash" },
					after = { "" },
					block_length = 0,
					track_change = {
						"Copyright ",
					},
					template = {
						require("auto-header").licenses.MIT,
					},
				},
			},
			projects = {
				{
					project_name = "Pillar ML",
					root = "~/Software/pillar-ml",
					create = true,
					update = true,
					template = {
						require("auto-header").licenses["gpl-3.0"],
					},
					data = {
						cp_holders = "Pillar ML <https://www.pillar.ml>",
					},
				},
				{
					project_name = "spren",
					root = "~/Software/pillar-ml/spren/",
					create = true,
					update = true,
					template = {
						"This source file was original a part of #project_name <#repo>",
						"",
						require("auto-header").licenses["gpl-3.0"],
					},
					data = {
						cp_holders = "Pillar ML <https://www.pillar.ml>",
						repo = "https://github.com/Pillar-ML/spren.git",
					},
				},
			},
		})
	end,
}
