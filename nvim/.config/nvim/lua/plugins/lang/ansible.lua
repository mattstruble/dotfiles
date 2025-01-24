return {
	{
		"williamboman/mason.nvim",
		opts = {
			ensure_installed = {
				"ansible-lint",
				"ansible-language-server",
			},
		},
	},
	{
		"mfussenegger/nvim-lint",
		opts = {
			linters_by_ft = {
				ansible = { "ansible_lint" },
			},
		},
	},
}
