return {
	"kkoomen/vim-doge",
	lazy = true,
	build = function()
		vim.fn["doge#install"]()
	end,
	config = function()
		vim.g.doge_doc_standard_python = "reST"
	end,
	keys = {
		{ "<leader>d", desc = "Doge Doc Generator" },
		{ "<Tab>", desc = "Next Todo" },
		{ "<S-Tab>", desc = "Prev Todo" },
	},
}
