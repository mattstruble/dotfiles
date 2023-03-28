--------------------------
-- TREESITTER
--------------------------

return {
	'nvim-treesitter/nvim-treesitter',
	lazy = false,
	config = function()
		require('nvim-treesitter.install').compilers = { "clang" }
		require('nvim-treesitter.configs').setup {
			ensure_installed = {
				"bash",
				"c",
				"cpp",
				"lua",
				"python",
				"help",
				"json",
                "yaml",
                "markdown",
                "vim",
                "dockerfile",
                "gitignore",
                "cmake",
                "sql",
                "terraform"
			},
			auto_install = true,
			highlight = {
				enable = true,
				additional_vim_regex_highlighting = false,
			},
			autopairs = { enable = true },
			indent = { enable = true },
            autotag = { enable = true }
		}
	end
}

