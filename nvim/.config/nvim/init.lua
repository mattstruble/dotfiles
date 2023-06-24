require("mestruble.core.options")
require("mestruble.core.keymaps")

--------------------------
-- LAZY SETUP
--------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

-- NOTE: This is in the wrong place but I don't want to keep fighting with it, tbh (lowercase global error).
opts = {
	ui = {
		border = "rounded",
	},
}

require("lazy").setup({
	spec = {
		{ "LazyVim/LazyVim", import = "lazyvim.plugins" },
		{ import = "lazyvim.plugins.extras.editor.flash" },
		{ import = "lazyvim.plugins.extras.util.project" },
		{ import = "plugins" },
	},
	ui = {
		border = "rounded",
	},
})

-- Automatically jump to the last cursor spot in file before exiting
vim.api.nvim_create_autocmd("BufReadPost", {
	callback = function()
		local mark = vim.api.nvim_buf_get_mark(0, '"')
		local lcount = vim.api.nvim_buf_line_count(0)
		if mark[1] > 0 and mark[1] <= lcount then
			pcall(vim.api.nvim_win_set_cursor, 0, mark)
		end
	end,
})
