--------------------------
-- MINI
--------------------------

return {
	"echasnovski/mini.starter",
	config = function()
		require("mini.starter").setup({
			header = "Welcome to Neovim",
		})
	end,
}
