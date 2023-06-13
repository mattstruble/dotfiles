return {
	{
		"Cassin01/wf.nvim",
		version = "*",
		lazy = true,
		enabled = false,
		config = function()
			require("wf").setup({
				theme = "default",
			})
		end,
		keys = {
			{ "<leader>wr", ":lua require('wf.builtin.register')()<CR>", desc = "[wf.nvim] register" },
			{ "<leader>wbu", ":lua require('wf.builtin.buffer')()<CR>", desc = "[wf.nvim] buffer" },
			{ "<leader>'", ":lua require('wf.builtin.mark')()<CR>", desc = "[wf.nvim] mark" },
			{
				"<leader>",
				":lua require('wf.builtin.which_key')({text_insert_in_advance = '<leader>'})<CR>",
				desc = "[wf.nvim] which-key /",
			},
			{ "<ctrl>-t", desc = "Toggle which-key with fuzzy-finder" },
		},
	},
	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		init = function()
			vim.o.timeout = true
			vim.o.timeoutlen = 300
		end,
		opts = {},
	},
}
