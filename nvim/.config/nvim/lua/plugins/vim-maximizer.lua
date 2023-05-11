-------------------
--- VIM MAXIMIZER
-------------------

return {
	"szw/vim-maximizer",
	lazy = true,
	events = "VeryLazy",
	keys = {
		{ "<leader>sm", ":MaximizerToggle<cr>", desc = "Maximizer" },
	},
}
