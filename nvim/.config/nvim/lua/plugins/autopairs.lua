--------------------------
-- NVIM AUTOPAIRS
--------------------------

return {
	"windwp/nvim-autopairs",
	lazy = false,
	config = function()
		require("nvim-autopairs").setup({
			check_ts = true,
			ts_config = {
				lua = { "string" },
			},
		})
	end,
}
