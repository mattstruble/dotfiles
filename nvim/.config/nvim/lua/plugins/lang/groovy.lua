vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	pattern = { "Jenkinsfile*" },
	desc = "Set groovy file types",
	command = "setfiletype groovy",
})

return {
	{
		"williamboman/mason.nvim",
		opts = {
			"groovy-language-server",
			"npm-groovy-lint",
		},
	},
	{
		"mfussenegger/nvim-lint",
		opts = {
			linters_by_ft = {
				groovy = { "npm-groovy-lint" },
			},
		},
	},
	{
		"stevearc/conform.nvim",
		opts = {
			formatters_by_ft = {
				groovy = { "npm-groovy-lint" },
			},
		},
	},
	{
		"ckipp01/nvim-jenkinsfile-linter",
		lazy = true,
		ft = "groovy",
		dependencies = { "nvim-lua/plenary.nvim" },
	},
}
