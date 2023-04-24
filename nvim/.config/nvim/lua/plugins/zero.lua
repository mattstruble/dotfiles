--------------------------
-- LSP ZERO
--------------------------

return {
	"VonHeikemen/lsp-zero.nvim",
	branch = "v1.x",
	dependencies = {
		{ "neovim/nvim-lspconfig" },
		{ "williamboman/mason.nvim" },
		{ "williamboman/mason-lspconfig.nvim" },

		-- auto completion
		{ "hrsh7th/nvim-cmp" },
		{ "hrsh7th/cmp-buffer" },
		{ "hrsh7th/cmp-path" },
		{ "saadparwaiz1/cmp_luasnip" },
		{ "hrsh7th/cmp-nvim-lsp" },
		{ "hrsh7th/cmp-nvim-lua" },

		-- snippets
		{ "L3MON4D3/LuaSnip" },
		{ "rafamadriz/friendly-snippets" },
	},
	config = function()
		local lsp = require("lsp-zero").preset({
			name = "minimal",
			set_lsp_keymaps = true,
			manage_nvim_cmp = true,
			suggest_lsp_servers = true,
		})

		local py = require("mestruble.lang.python")
		local cmp = require("cmp")
		local cmp_select = { behavior = cmp.SelectBehavior.Select }

		lsp.ensure_installed({
			"bashls",
			"cmake",
			"docker_compose_language_service",
			"dockerls",
			-- "fixjson",
			"ltex",
			"lua_ls",
			"marksman",
			-- "pylsp",
			"pyright",
			"sqlls",
			"taplo",
			"terraformls",
			-- "vim-language-server",
			-- "yamlfmt",
			-- "yamllint",
			"yamlls",
			-- "groovyls",
			-- "black",
			"ruff-lsp",
		})

		lsp.set_preferences({
			sign_icons = {
				error = " ",
				warn = " ",
				hint = "ﴞ ",
				info = " ",
			},
		})

		-- resolve global vim issues
		lsp.configure("lua-language-server", {
			settings = {
				Lua = {
					diagnostics = {
						globals = { "vim" },
					},
				},
			},
		})

		-- pass python .venv into pyright
		lsp.configure("pyright", {
			settings = {
				python = {
					analysis = {
						typeCheckingMode = "basic",
						useLibraryCodeForTypes = true,
						completeFunctionParens = true,
					},
				},
			},
			on_new_config = function(new_config, new_root_dir)
				py.env(new_root_dir)
				new_config.settings.python.pythonPath = vim.fn.exepath("python")
				new_config.settings.python.analysis.extraPaths = { py.pep582(new_root_dir) }
			end,
		})

		local cmp_mappings = lsp.defaults.cmp_mappings({
			["<C-p>"] = cmp.mapping.select_prev_item(cmp_select),
			["<C-n>"] = cmp.mapping.select_next_item(cmp_select),
			["<C-Space>"] = cmp.mapping.complete(),
		})

		cmp_mappings["<Tab>"] = nil
		cmp_mappings["<S-Tab>"] = nil

		lsp.setup_nvim_cmp({
			preselect = "none",
			completion = {
				completeopt = "menu, menuone, noinsert, noselect",
			},
			mapping = cmp_mappings,
		})

		lsp.on_attach(function(client, bufnr)
			local opts = { buffer = bufnr, remap = false }
			vim.keymap.set("n", "gd", function()
				vim.lsp.buf.definition()
			end, opts)
			vim.keymap.set("n", "gr", function()
				vim.lsp.buf.references()
			end, opts)
			vim.keymap.set("n", "gD", function()
				vim.lsp.buf.declaration()
			end, opts)
			vim.keymap.set("n", "K", function()
				vim.lsp.buf.hover()
			end, opts)
			vim.keymap.set("n", "<leader>rn", function()
				vim.lsp.buf.rename()
			end, opts)
			vim.keymap.set("n", "<leader>ca", function()
				vim.lsp.buf.code_action()
			end, opts)
			vim.keymap.set("n", "]d", function()
				vim.diagnostic.goto_prev()
			end, opts)
			vim.keymap.set("n", "[d", function()
				vim.diagnostic.goto_next()
			end, opts)
		end)

		lsp.nvim_workspace()
		lsp.setup()
	end,
}
