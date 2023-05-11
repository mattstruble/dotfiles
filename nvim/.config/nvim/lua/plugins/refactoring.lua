--------------------
-- REFACTORING
--------------------

return {
	"ThePrimeagen/refactoring.nvim",
	lazy = true,
	events = "VeryLazy",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
	},
	config = function()
		require("refactoring").setup()
	end,
}
