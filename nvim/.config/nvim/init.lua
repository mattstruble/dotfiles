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

require("lazy").setup("plugins", opts)

--------------------------
-- COLOR SCHEME
--------------------------
vim.cmd([[ colorscheme nightfly ]])

vim.g.nightflyItalics = true
