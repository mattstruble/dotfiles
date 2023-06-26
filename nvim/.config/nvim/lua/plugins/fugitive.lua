--------------------
-- FUGITIVE
-- https://github.com/ThePrimeagen/init.lua/blob/master/after/plugin/fugitive.lua
--------------------

return {
	"tpope/vim-fugitive",
	lazy = true,
	cmd = "Git",
	keys = {
		{ "<leader>gs", vim.cmd.Git, desc = "Git fugitive" },
	},
	config = function()
		local mestruble_fugitive = vim.api.nvim_create_augroup("mestruble_fugitive", {})
		local autocmd = vim.api.nvim_create_autocmd

		autocmd("BufWinEnter", {
			group = mestruble_fugitive,
			pattern = "*",
			callback = function()
				if vim.bo.ft ~= "fugitive" then
					return
				end

				local bufnr = vim.api.nvim_get_current_buf()
				local opts = { buffer = bufnr, remap = false }

				vim.keymap.set("n", "cc", function()
					vim.cmd.Git("commit", "-s")
				end, opts)

				vim.keymap.set("n", "<leader>p", function()
					vim.cmd.Git("push")
				end, opts)

				vim.keymap.set("n", "<leader>P", function()
					vim.cmd.Git({ "pull", "--rebase" })
				end, opts)

				vim.keymap.set("n", "<leader>t", ":Git push -u origin", opts)
			end,
		})
	end,
}
