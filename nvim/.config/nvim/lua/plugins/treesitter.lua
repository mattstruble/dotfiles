--------------------------
-- TREESITTER
--------------------------

return {
	{
		"nvim-treesitter/nvim-treesitter",
		lazy = true,
		module = true,
		event = { "BufReadPost", "BufNewFile" },
		dependencies = {
			"https://gitlab.com/HiPhish/rainbow-delimiters.nvim.git",
			"nvim-treesitter/nvim-treesitter-context",
		},
		cmd = {
			"TSInstall",
			"TSInstallInfo",
			"TSUpdate",
			"TSBufEnable",
			"TSBufDisable",
			"TSEnable",
			"TSDisable",
			"TSModuleInfo",
		},
		opts = {
			sync_install = false,
			auto_install = true,
			highlight = {
				enable = true,
				additional_vim_regex_highlighting = false,
			},
			autopairs = { enable = true },
			indent = { enable = true },
			autotag = { enable = true },
		},
	},
}
