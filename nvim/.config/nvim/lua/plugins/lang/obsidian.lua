return {
	"epwalsh/obsidian.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	version = "*",
	lazy = true,
	ft = "markdown",
	opts = {
		completion = {
			nvim_cmp = true,
		},
		workspaces = {
			{
				name = "vault",
				path = function()
					return vim.env.OBSIDIAN_VAULT
				end,
			},
		},
	},
}
