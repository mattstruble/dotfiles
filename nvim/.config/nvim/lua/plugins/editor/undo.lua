--------------------------
-- UNDO TREE
--------------------------

return {
	{
		"tzachar/highlight-undo.nvim",
		lazy = true,
		event = { "BufReadPost", "BufNewFile" },
		config = function()
			require("highlight-undo").setup({})
		end,
	},
	{
		"mbbill/undotree",
		lazy = true,
		keys = {
			{ "<leader>u", vim.cmd.UndotreeToggle, desc = "Undo Tree" },
		},
	},
}
