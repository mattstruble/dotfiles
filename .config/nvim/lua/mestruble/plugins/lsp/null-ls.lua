local setup, null_ls = pcall(require, "null-ls")
if not setup then
	return
end

local formatting = null_ls.builtins.formatting
local diagonistics = null_ls.builtins.diagnostics

-- to setup format on save
local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

null_ls.setup({
	sources = {
		formatting.prettier,
		formatting.stylua,
		formatting.black,
		formatting.isort,
		formatting.autoflake,
		formatting.beautysh,
		formatting.codespell,
		formatting.json_tool,
		formatting.latexindent,
		formatting.terraform_fmt,
		formatting.trim_whitespace,
		formatting.sqlfluff,
		diagonistics.pydocstyle,
		diagonistics.checkmake,
		diagonistics.chktex,
		diagonistics.codespell,
		diagonistics.flake8,
		diagonistics.hadolint,
		diagonistics.markdownlint,
		diagonistics.sqlfluff,
		diagonistics.actionlint,
		diagonistics.buildifier,
		diagonistics.mypy,
		diagonistics.pylint,
		diagonistics.terraform_validate,
	},
	-- configure format on save
	on_attach = function(curr_client, bufnr)
		if curr_client.supports_method("textDocument/formatting") then
			vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
			vim.api.nvim_create_autocmd("BufWritePre", {
				group = augroup,
				buffer = bufnr,
				callback = function()
					vim.lsp.buf.format({
						filter = function(client)
							return client.name == "null-ls"
						end,
						bufnr = bufnr,
					})
				end,
			})
		end
	end,
})
