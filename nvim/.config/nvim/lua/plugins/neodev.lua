--------------------------
-- NEO DEV
--------------------------

return {
	"folke/neodev.nvim",
	lazy = true,
	event = "VeryLazy",
	config = function()
		require("neodev").setup({
			library = {
				plugins = {
					"nvim-dap-ui",
				},
				types = true,
			},
		})
	end,
}
