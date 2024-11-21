-------------------
-- INC RENAME
-------------------

return {
	"smjonas/inc-rename.nvim",
	lazy = true,
	event = { "BufReadPost", "BufNewFile" },
	opts = {
		input_buffer_type = "dressing",
	},
	keys = {
		{
			"<leader>rn",
			function()
				return ":IncRename " .. vim.fn.expand("<cword>")
			end,
			desc = "[R]e[N]ame",
		},
	},
}
