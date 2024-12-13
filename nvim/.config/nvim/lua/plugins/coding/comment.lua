--------------------------
-- COMMENT
--------------------------

return {
	"numtoStr/Comment.nvim",
	lazy = true,
	-- event = { "BufReadPost", "BufNewFile" },
	config = true,
	keys = {
		{ "gcc", desc = "Toggle linewise comment" },
		{ "gbc", desc = "Toggle blockwise comment" },
		{ "gc", mode = "v", desc = "Toggle linewise comment" },
		{ "gb", mode = "v", desc = "Toggle blockwise comment" },
	},
}
