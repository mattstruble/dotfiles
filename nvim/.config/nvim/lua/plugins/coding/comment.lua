--------------------------
-- COMMENT
--------------------------

return {
	"numtoStr/Comment.nvim",
	lazy = true,
	config = true,
	keys = {
		{ "gcc", desc = "Toggle linewise comment" },
		{ "gbc", desc = "Toggle blockwise comment" },
		{ "gc", mode = "v", desc = "Toggle linewise comment" },
		{ "gb", mode = "v", desc = "Toggle blockwise comment" },
	},
}
