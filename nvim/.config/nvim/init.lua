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

-- require("lazy").setup("plugins", opts)
require("lazy").setup({
	spec = {
		{
			"LazyVim/LazyVim",
			opts = {
				icons = {
					diagnostics = {
						Error = " ",
						Warn = " ",
						Hint = "󰌶 ",
						Info = " ",
					},
				},
			},
		},
		{ import = "lazyvim.plugins" },
		{ import = "lazyvim.plugins.extras.lang.python" },
		{ import = "lazyvim.plugins.extras.lang.docker" },
		{ import = "lazyvim.plugins.extras.lang.terraform" },
		{ import = "lazyvim.plugins.extras.lang.tex" },
		{ import = "lazyvim.plugins.extras.lang.yaml" },
		{ import = "lazyvim.plugins.extras.lang.json" },
		{ import = "lazyvim.plugins.extras.ui.mini-starter" },
		{ import = "lazyvim.plugins.extras.formatting.prettier" },
		{ import = "plugins" },

		{
			"hrsh7th/nvim-cmp",
			opts = function(_, opts)
				local cmp = require("cmp")
				local cmp_select = { behavior = cmp.SelectBehavior.Select }

				opts.mapping["<C-p>"] = cmp.mapping.select_prev_item(cmp_select)
				opts.mapping["<C-n>"] = cmp.mapping.select_next_item(cmp_select)
				opts.mapping["<C-Space>"] = cmp.mapping.complete()
				opts.mapping["<Tab>"] = nil
				opts.mapping["<S-Tab>"] = nil
			end,
		},

		-- nvim-lspconfig global configurations
		{
			"neovim/nvim-lspconfig",
            -- stylua: ignore
			init = function()
				local keys = require("lazyvim.plugins.lsp.keymaps").get()
				keys[#keys + 1] = { "gd", function() vim.lsp.buf.definition() end }
				keys[#keys + 1] = { "gr", function() vim.lsp.buf.references() end }
				keys[#keys + 1] = { "gD", function() vim.lsp.buf.declaration() end }
				keys[#keys + 1] = { "K", function() vim.lsp.buf.hover() end }
				keys[#keys + 1] = { "<leader>rn", function() vim.lsp.buf.rename() end }
				keys[#keys + 1] = { "<leader>ca", function() vim.lsp.buf.code_action() end }
				keys[#keys + 1] = { "gl", function() vim.diagnostic.open_float() end }
				keys[#keys + 1] = { "]d", function() vim.diagnostic.goto_next() end }
				keys[#keys + 1] = { "[d", function() vim.diagnostic.goto_prev() end }
				keys[#keys + 1] = { "<leader>f", function() vim.lsp.buf.format({ async = true }) end }
			end,
			opts = {
				diagnostics = {
					underline = false,
					update_in_insert = false,
					severity_sort = true,
					virtual_text = {
						severity = vim.diagnostic.severity.ERROR,
						spacing = 4,
						prefix = "",
					},
					float = {
						focusable = false,
						style = "minimal",
						border = "rounded",
						source = "always",
						header = "",
						prefix = "",
					},
				},
				inlay_hints = { enabled = false },
				autoformate = true,
				format_notify = false,
			},
		},
	},
	ui = {
		border = "rounded",
	},
}, opts)

-- rounded borders
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
	border = "rounded",
})

vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
	border = "rounded",
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
