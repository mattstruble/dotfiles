--------------------------
-- UNDO TREE
--------------------------

return {
	"mbbill/undotree",
	lazy = true,
	events = "VeryLazy",
	keys = {
		{ "<leader>u", vim.cmd.UndotreeToggle, desc = "Undo Tree" },
	},
}
