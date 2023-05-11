--------------------------
-- UNDO TREE
--------------------------

return {
	"mbbill/undotree",
	lazy = true,
	keys = {
		{ "<leader>u", vim.cmd.UndotreeToggle, desc = "Undo Tree" },
	},
}
