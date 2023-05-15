--------------------------
-- NEO DEV
--------------------------

return {
	"folke/neodev.nvim",
	lazy = true,
	event = "InsertEnter",
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
