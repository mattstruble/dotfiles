return {
	{
		"williamboman/mason.nvim",
		opts = function(_, opts)
			table.insert(opts.ensure_installed, "rust-analyzer")
			table.insert(opts.ensure_installed, "codelldb")
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter",
		opts = function(_, opts)
			table.insert(opts.ensure_installed, "rust")
		end,
	},
	{
		"nvimtools/none-ls.nvim",
		opts = function(_, opts)
			local nls = require("null-ls")

			table.insert(opts.sources, nls.builtins.formatting.rustfmt)
		end,
	},
	{
		"neovim/nvim-lspconfig",
		opts = {
			servers = {
				rust_analyzer = {
					["rust-analyzer"] = {
						diagnostics = {
							enable = true,
						},
					},
				},
			},
		},
	},
	{
		"simrat39/rust-tools.nvim",
		ft = "rust",
		config = function()
			local rt = require("rust-tools")
			rt.setup({
				on_attach = function(_, bufnr)
					vim.keymap.set("n", "<C-space>", rt.hover_actions.hover_actions, { buffer = bufnr })
					vim.keymap.set("n", "<leader>a", rt.code_action_group.code_action_group, { buffer = bufnr })
				end,
			})
		end,
	},
	{
		"mfussenegger/nvim-dap",
		opts = function(_, opts)
			if opts.configurations == nil then
				opts.configurations = {}
			end
			opts.configurations.rust = {
				name = "Launch file",
				type = "codelldb",
				request = "launch",
				program = function()
					return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
				end,
				cwd = "${workspaceFolder}",
				stopOnEntry = false,
			}
		end,
	},
}
