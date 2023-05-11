--------------------------
-- COMMENT
--------------------------

return {
	"numtoStr/Comment.nvim",
	lazy = true,
	event = "VeryLazy",
	config = function()
		require("Comment").setup()
	end,
}
