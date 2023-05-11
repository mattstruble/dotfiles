--------------------------
-- NVIM TREE
--------------------------

return {
	"nvim-tree/nvim-tree.lua",
	lazy = true,
	config = function()
		vim.g.loaded = 1
		vim.g.loaded_netrwPlugin = 1

		vim.cmd([[ highlight NvimTreeIndentMarker guifg=#3FC5ff ]])

		require("nvim-tree").setup({
			hijack_cursor = true,
			filesystem_watchers = {
				enable = true,
			},
			update_focused_file = {
				enable = true,
			},
			view = {
				apdaptive_size = false,
				preserve_window_proportions = true,
			},
			filters = {
				custom = { ".git" },
				exclude = { ".gitignore", ".github" },
			},
			renderer = {
				indent_markers = {
					enable = true,
				},
				icons = {
					webdev_colors = true,

					show = {
						folder_arrow = false,
					},
					glyphs = {
						folder = {
							arrow_closed = "",
							arrow_open = "",
						},
					},
				},
			},
			actions = {
				open_file = {
					window_picker = {
						enable = false,
					},
				},
			},
			git = {
				ignore = true, -- show gitignore files
			},
		})
	end,
	keys = {
		{ "<leader>e", ":NvimTreeToggle<CR>", desc = "NvimTree" },
	},
}
