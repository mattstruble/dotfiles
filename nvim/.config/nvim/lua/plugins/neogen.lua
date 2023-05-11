return {
	"danymat/neogen",
	lazy = true,
	dependencies = "nvim-treesitter/nvim-treesitter",
	config = function()
		require("neogen").setup({
			snippet_engine = "luasnip",
			languages = {
				python = {
					template = {
						annotation_convention = "reST",
					},
				},
			},
		})
	end,
	keys = {
		{ "<leader>nf", ":lua require('neogen').generate()<cr>", desc = "Generate function docs" },
		{ "<leader>nc", ":lua require('neogen').generate({type = 'class'})<cr>", desc = "Generate class docs" },
	},
}
