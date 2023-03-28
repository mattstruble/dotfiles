--------------------------
-- NULL-LS
--------------------------

return {
	"jose-elias-alvarez/null-ls.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"jayp0521/mason-null-ls.nvim",
	},
	config = function()
		local null_ls = require("null-ls")

		local code_actions = null_ls.builtins.code_actions -- code actions sources
		local diagnostics = null_ls.builtins.diagnostics -- diagnostics sources
		local formatting = null_ls.builtins.formatting -- formatting sources
		local hover = null_ls.builtins.hover -- hover sources
		local completion = null_ls.builtins.completion -- completion sources
		local spell = null_ls.builtins.completion.spell -- spelling sources

		local sources = {
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
			diagnostics.pydocstyle,
			diagnostics.checkmake,
			diagnostics.chktex,
			diagnostics.codespell,
			diagnostics.flake8,
			diagnostics.hadolint,
			diagnostics.markdownlint,
			diagnostics.sqlfluff,
			diagnostics.actionlint,
			diagnostics.buildifier,
			diagnostics.mypy,
			diagnostics.pylint,
			diagnostics.terraform_validate,
		}

		null_ls.setup({ 
            sources = sources, 
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
            end
        })
	end,
}
