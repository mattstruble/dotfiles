return {
	"danymat/neogen",
	lazy = true,
	dependencies = "nvim-treesitter/nvim-treesitter",
	config = function()
		local opts = { noremap = true, silent = true }
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

		vim.keymap.set("n", "<leader>nf", ":lua require('neogen').generate()<CR>", opts)
		vim.keymap.set("n", "<leader>nc", ":lua require('neogen').generate({type = 'class'})<CR>", opts)
	end,
}
