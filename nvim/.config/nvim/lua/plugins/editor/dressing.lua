return {
	"stevearc/dressing.nvim",
	event = "VeryLazy",
	config = function()
		require("dressing").setup({
			select = {
				telescope = require("telescope.themes").get_cursor({
					layout_config = { width = 120 },
				}),
			},
		})
	end,
}
