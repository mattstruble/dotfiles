return {
	"polarmutex/git-worktree.nvim",
	dependencies = "nvim-telescope/telescope.nvim",
	config = function()
		require("git-worktree").setup()
		require("telescope").load_extension("git_worktree")
	end,
	keys = {
		{
			"<leader>sw",
			"<cmd>lua require('telescope').extensions.git_worktree.git_worktrees()<cr>",
			desc = "[S]earch local [W]orktrees",
		},
		{
			"<leader>sW",
			"<cmd>lua require('telescope').extensions.git_worktree.create_git_worktree()<cr>",
			desc = "[S]earch remote [W]orktrees",
		},
	},
}
