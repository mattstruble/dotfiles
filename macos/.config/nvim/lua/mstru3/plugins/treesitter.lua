local status, tresitter = pcall(require, "nvim-treesitter.configs")
if not status then
	return
end

tresitter.setup({
	highlight = { enable = true },
	indent = { enable = true },
	autotag = { enable = true },
	ensure_installed = {
		"json",
		"yaml",
		"markdown",
		"bash",
		"lua",
		"vim",
		"dockerfile",
		"gitignore",
		"python",
		"gitignore",
		"cmake",
		"sql",
		"terraform",
	},
	auto_install = true,
})
