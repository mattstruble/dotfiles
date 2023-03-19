local lspconfig_status, lspconfig = pcall(require, "lspconfig")
if not lspconfig_status then
	return
end

local cmp_nvim_lsp_status, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if not cmp_nvim_lsp_status then
	return
end

local py = require("mestruble.lang.python")

local keymap = vim.keymap

local on_attach = function(client, bufnr)
	-- keybind options
	local opts = { noremap = true, silent = true, buffer = bufnr }

	-- set keybinds
	keymap.set("n", "gr", "<cmd>Telescope lsp_references<CR>", opts) -- show definition, references
	keymap.set("n", "gD", vim.lsp.buf.declaration, opts) -- got to declaration
	keymap.set("n", "gd", "<cmd>Telescope lsp_definitions<CR>", opts) -- see definition and make edits in window
	keymap.set("n", "gi", "<cmd>Telescope lsp_implementations<CR>", opts) -- go to implementation
	keymap.set("n", "gt", "<cmd>Telescope lsp_type_definitions<CR>", opts) -- go to implementation
	keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts) -- see available code actions
	keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts) -- see available code actions, in visual mode will apply to selection
	keymap.set("n", "<leader>rn", ":IncRename ", opts) -- smart rename
	keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", opts) -- show  diagnostics for file
	keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts) -- show diagnostics for line
	keymap.set("n", "[d", vim.diagnostic.goto_prev, opts) -- jump to previous diagnostic in buffer
	keymap.set("n", "]d", vim.diagnostic.goto_next, opts) -- jump to next diagnostic in buffer
	keymap.set("n", "K", vim.lsp.buf.hover, opts) -- show documentation for what is under cursorend
end
-- used to enable autocompletion
local capabilities = cmp_nvim_lsp.default_capabilities()

local signs = { Error = " ", Warn = " ", Hint = "ﴞ ", Info = " " }
for type, icon in pairs(signs) do
	local hl = "DiagnosticSign" .. type
	vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
end

lspconfig["bashls"].setup({
	server = {
		capabilities = capabilities,
		on_attach = on_attach,
	},
})

lspconfig["cmake"].setup({
	server = {
		capabilities = capabilities,
		on_attach = on_attach,
	},
})

lspconfig["dockerls"].setup({
	server = {
		capabilities = capabilities,
		on_attach = on_attach,
	},
})

lspconfig["docker_compose_language_service"].setup({
	server = {
		capabilities = capabilities,
		on_attach = on_attach,
	},
})

lspconfig["ltex"].setup({
	server = {
		capabilities = capabilities,
		on_attach = on_attach,
	},
})

lspconfig["marksman"].setup({
	server = {
		capabilities = capabilities,
		on_attach = on_attach,
	},
})

lspconfig["pyright"].setup({
	settings = {
		python = {
			analysis = {
				typeCheckingMode = "basic", -- ["off", "basic", "strict"]
				useLibraryCodeForTypes = true,
				completeFunctionParens = true,
			},
		},
	},
	server = {
		capabilities = capabilities,
		on_attach = on_attach,
	},
	on_new_config = function(new_config, new_root_dir)
		py.env(new_root_dir)
		new_config.settings.python.pythonPath = vim.fn.exepath("python")
		new_config.settings.python.analysis.extraPaths = { py.pep582(new_root_dir) }
	end,
})

lspconfig["sqlls"].setup({
	server = {
		capabilities = capabilities,
		on_attach = on_attach,
	},
})

lspconfig["taplo"].setup({
	server = {
		capabilities = capabilities,
		on_attach = on_attach,
	},
})

lspconfig["terraformls"].setup({
	server = {
		capabilities = capabilities,
		on_attach = on_attach,
	},
})

lspconfig["yamlls"].setup({
	server = {
		capabilities = capabilities,
		on_attach = on_attach,
	},
})

-- configure lua server (with special settings)
lspconfig["lua_ls"].setup({
	capabilities = capabilities,
	on_attach = on_attach,
	settings = { -- custom settings for lua
		Lua = {
			-- make the language server recognize "vim" global
			diagnostics = {
				globals = { "vim" },
			},
			workspace = {
				-- make language server aware of runtime files
				library = {
					[vim.fn.expand("$VIMRUNTIME/lua")] = true,
					[vim.fn.stdpath("config") .. "/lua"] = true,
				},
			},
		},
	},
})
