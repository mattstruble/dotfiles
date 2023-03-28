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

		--{ "jose-elias-alvarez/null-ls.nvim" },
		--{ "jayp0521/mason-null-ls.nvim" },
	},
	config = function()
		local lsp = require("lsp-zero").preset({
			name = "minimal",
			set_lsp_keymaps = true,
			manage_nvim_cmp = true,
			suggest_lsp_servers = false,
		})

		local py = require("mestruble.lang.python")
		local cmp = require("cmp")
		local cmp_select = { behavior = cmp.SelectBehavior.Select }

		lsp.ensure_installed({
			"bashls",
			"cmake",
			"dockerls",
			"docker_compose_language_service",
			-- "groovyls",
			"ltex",
			"marksman",
			"pylsp",
			"pyright",
			"sqlls",
			"taplo",
			"terraformls",
			"yamlls",
			"lua_ls",
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

		lsp.setup_nvim_cmp({
			preselect = "none",
			completion = {
				completeopt = "menu, menuone, noinsert, noselect",
			},
			mapping = lsp.defaults.cmp_mappings({
				["<C-p>"] = cmp.mapping.select_prev_item(cmp_select),
				["<C-n>"] = cmp.mapping.select_next_item(cmp_select),
				["<C-y>"] = cmp.mapping.confirm({ select = true }),
				["<C-Space>"] = cmp.mapping.complete(),
			}),
		})

		lsp.nvim_workspace()
		lsp.setup()
	end,
}
