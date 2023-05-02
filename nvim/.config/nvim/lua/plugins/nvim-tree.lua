--------------------------
-- NVIM TREE
--------------------------

return {
	"nvim-tree/nvim-tree.lua",
	config = function()
		vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>")

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
				ignore = false, -- show gitignore files
			},
		})
	end,
}
