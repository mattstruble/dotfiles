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

		local py = require("mestruble.lang.python")

		local code_actions = null_ls.builtins.code_actions -- code actions sources
		local diagnostics = null_ls.builtins.diagnostics -- diagnostics sources
		local formatting = null_ls.builtins.formatting -- formatting sources
		local hover = null_ls.builtins.hover -- hover sources
		local completion = null_ls.builtins.completion -- completion sources
		local spell = null_ls.builtins.completion.spell -- spelling sources

		local sources = {
			code_actions.refactoring,
			code_actions.gitsigns,

			completion.luasnip,
			completion.spell,

			formatting.beautysh,
			formatting.black,
			formatting.buildifier,
			formatting.codespell,
			formatting.fixjson,
			formatting.json_tool,
			formatting.latexindent,
			-- formatting.lua_format,
			formatting.markdown_toc,
			formatting.markdownlint,
			formatting.prettier,
			-- formatting.pyflyby,
			-- formatting.remark,
			formatting.ruff,
			formatting.shellharden,
			formatting.sqlfluff.with({
				extra_args = { "--dialect", "snowflake" },
			}),
			formatting.stylua,
			formatting.terraform_fmt,
			formatting.trim_whitespace,
			formatting.yamlfmt.with({
				args = "",
				extra_args = { "-formatter", "indent=4,retain_line_breaks=true" },
			}),

			diagnostics.actionlint,
			diagnostics.buildifier,
			diagnostics.checkmake,
			diagnostics.chktex,
			diagnostics.codespell,
			diagnostics.hadolint,
			diagnostics.markdownlint,
			diagnostics.mypy.with({
				extra_args = { "--ignore-missing-imports" },
			}),
			diagnostics.ruff,
			diagnostics.shellcheck,
			diagnostics.sqlfluff.with({
				extra_args = { "--dialect", "snowflake" },
			}),
			diagnostics.terraform_validate,
			diagnostics.vulture,
			diagnostics.write_good,
			-- diagnostics.yamllint,
		}

		local lsp_formatting = function(bufnr)
			vim.lsp.buf.format({
				filter = function(client)
					return client.name == "null-ls"
				end,
				bufnr = bufnr,
			})
		end

		local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

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
							lsp_formatting(bufnr)
						end,
					})
				end
			end,
		})
	end,
}
