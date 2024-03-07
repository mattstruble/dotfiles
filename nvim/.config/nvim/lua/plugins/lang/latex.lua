return {
	{
		"williamboman/mason.nvim",
		opts = function(_, opts)
			table.insert(opts.ensure_installed, "ltex-ls")
		end,
	},
	{
		"nvimtools/none-ls.nvim",
		opts = function(_, opts)
			local nls = require("null-ls")
		end,
	},
	{
		"abeleinin/papyrus",
		lazy = true,
		config = function()
			vim.g.papyrus_latex_engine = "pdflatex"
			vim.g.papyrus_viewer = "zathura"
		end,
        -- stylua: ignore
        keys = {
            { "<leader>pc", ":PapyrusCompile<cr>", desc = "Papyrus Compile"},
            { "<leader>pa", ":PapyrusAutoCompile<cr>", desc = "Papyrus Auto Compile"},
            { "<leader>pv", ":PapyrusView<cr>", desc = "Papyrus View"},
            { "<leader>ps", ":PapyrusStart<cr>", desc = "Papyrus Start"}
        },
	},
}
