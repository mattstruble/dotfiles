return {
	"epwalsh/obsidian.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	version = "*",
	lazy = true,
	ft = "markdown",
	opts = {
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
