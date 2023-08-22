--------------------------
-- TREESITTER
--------------------------

return {
	{
		"nvim-treesitter/nvim-treesitter-context",
		lazy = true,
	},
	{
		"nvim-treesitter/nvim-treesitter",
		lazy = true,
		module = true,
		event = { "BufReadPost", "BufNewFile" },
		dependencies = {
			-- "HiPhish/nvim-ts-rainbow2",
			"https://gitlab.com/HiPhish/rainbow-delimiters.nvim.git",
			-- "HiPhish/rainbow-delimiters",
			-- "mrjones2014/nvim-ts-rainbow",
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
		-- build = ":TSUpdate",
		-- config = function()
		-- 	require("nvim-treesitter.install").compilers = { "clang" }
		-- 	require("nvim-treesitter.configs").setup({
		-- 		ensure_installed = {
		-- 			"bash",
		-- 			"c",
		-- 			"cpp",
		-- 			"lua",
		-- 			"python",
		-- 			"help",
		-- 			"json",
		-- 			"yaml",
		-- 			"markdown",
		-- 			"vim",
		-- 			"dockerfile",
		-- 			"gitignore",
		-- 			"cmake",
		-- 			"sql",
		-- 			"terraform",
		-- 		},
		-- 		sync_install = false,
		-- 		auto_install = true,
		-- 		highlight = {
		-- 			enable = true,
		-- 			additional_vim_regex_highlighting = false,
		-- 		},
		-- 		autopairs = { enable = true },
		-- 		indent = { enable = true },
		-- 		autotag = { enable = true },
		-- 		rainbow = {
		-- 			enable = true,
		-- 			extended_mode = true,
		-- 			max_file_lines = nil,
		-- 			strategy = require("ts-rainbow").strategy.global,
		-- 		},
		-- 	})
		-- end,
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
			-- rainbow = {
			-- 	enable = true,
			-- 	extended_mode = true,
			-- 	max_file_lines = nil,
			-- 	strategy = require("ts-rainbow").strategy.global,
			-- },
		},
	},
}
