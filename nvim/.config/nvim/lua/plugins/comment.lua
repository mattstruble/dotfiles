--------------------------
-- COMMENT
--------------------------

return {
	"numtoStr/Comment.nvim",
	lazy = true,
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		require("Comment").setup()
	end,
}
