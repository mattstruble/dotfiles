vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	pattern = { "Jenkinsfile*" },
	desc = "Set groovy file types",
	command = "setfiletype groovy",
})

return {
	{
		"williamboman/mason.nvim",
		opts = function(_, opts)
			table.insert(opts.ensure_installed, "groovy-language-server")
		end,
	},
	{
		"ckipp01/nvim-jenkinsfile-linter",
		lazy = true,
		ft = "groovy",
		dependencies = { "nvim-lua/plenary.nvim" },
	},
}
