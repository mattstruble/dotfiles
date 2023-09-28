return {
	"Wansmer/symbol-usage.nvim",
	name = "symbol-usage",
	event = "BufReadPre", -- need run before LspAttach if you use nvim 0.9. On 0.10 use 'LspAttach'
	opts = {
		vt_position = "textwidth",
		request_pending_text = false,
	},
}
