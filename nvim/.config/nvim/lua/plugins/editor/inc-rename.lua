-------------------
-- INC RENAME
-------------------

return {
	"smjonas/inc-rename.nvim",
	lazy = true,
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		require("inc_rename").setup()
	end,
}
