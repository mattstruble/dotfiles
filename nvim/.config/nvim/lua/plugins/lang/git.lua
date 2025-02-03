return {
	{
		"williamboman/mason.nvim",
		opts = {
			ensure_installed = {
				"actionlint",
				"gitlint",
			},
		},
	},
	{
		"mfussenegger/nvim-lint",
		opts = {
			linters_by_ft = {
				yaml = { "actionlint" },
				git = { "gitlint" },
			},
		},
	},
	{
		"wintermute-cell/gitignore.nvim",
		enabled = false,
		lazy = true,
		dependencies = {
			"nvim-telescope/telescope.nvim",
		},
		keys = {
			{ "<leader>gi", "<cmd>Gitignore<CR>", desc = "Generate gitignore" },
		},
	},
	{
		"pwntester/octo.nvim",
		lazy = true,
		cmd = "Octo",
		enabled = false,
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope.nvim",
			"nvim-tree/nvim-web-devicons",
		},
		config = function()
			require("octo").setup()
		end,
	},
	{
		"tpope/vim-fugitive",
		lazy = false,
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

					vim.keymap.set("n", "<leader>cc", function()
						vim.cmd.Git("commit -s")
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
	},
	{
		"lewis6991/gitsigns.nvim",
		lazy = true,
		event = "VeryLazy",
		config = function()
			require("gitsigns").setup()
		end,
	},
}
