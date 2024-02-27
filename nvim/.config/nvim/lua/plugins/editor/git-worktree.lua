return {
	"polarmutex/git-worktree.nvim",
	dependencies = "nvim-telescope/telescope.nvim",
	config = function()
		require("git-worktree").setup()
		require("telescope").load_extension("git_worktree")
	end,
	keys = {
		{
			"<leader>sr",
			"<cmd>lua require('telescope').extensions.git_worktree.git_worktrees()<cr>",
			desc = "List worktrees",
		},
		{
			"<leader>sR",
			"<cmd>lua require('telescope').extensions.git_worktree.create_git_worktree()<cr>",
			desc = "Create worktree",
		},
	},
}
