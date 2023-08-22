--------------------------
-- NVIM TREE
--------------------------

return {
	"nvim-tree/nvim-tree.lua",
	lazy = true,
	cmd = {
		"NvimTreeToggle",
		"NvimTreeOpen",
		"NvimTreeFindFile",
		"NvimTreeFindFileToggle",
		"NvimTreeRefresh",
	},
	enabled = false,
	config = function()
		vim.g.loaded = 1
		vim.g.loaded_netrwPlugin = 1

		vim.cmd([[ highlight NvimTreeIndentMarker guifg=#3FC5ff ]])
		require("nvim-tree").setup({
			-- sync_root_with_cwd = true,
			respect_buf_cwd = true,
			update_focused_file = {
				enable = true,
				update_root = true,
			},
			hijack_cursor = true,
			filesystem_watchers = {
				enable = true,
			},
			update_focused_file = {
				enable = true,
			},
			view = {
				adaptive_size = false,
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
