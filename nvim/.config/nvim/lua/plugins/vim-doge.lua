return {
	"kkoomen/vim-doge",
	run = function()
		vim.fn["doge#install"]()
	end,
	config = function()
		vim.g.doge_doc_standard_python = "sphinx"
	end,
}
