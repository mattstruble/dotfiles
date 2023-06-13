return {
	"wintermute-cell/gitignore.nvim",
	lazy = true,
	dependencies = {
		"nvim-telescope/telescope.nvim",
	},
	keys = {
		{ "<leader>gi", "<cmd>Gitignore<CR>", desc = "Generate gitignore" },
	},
}
