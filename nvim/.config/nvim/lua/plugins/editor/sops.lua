return {
	"lucidph3nx/nvim-sops",
	event = { "BufEnter" },
	keys = {
		{ "<leader>fe", vim.cmd.SopsEncrypt, desc = "[F]ile [E]ncrypt" },
		{ "<leader>fd", vim.cmd.SopsDecrypt, desc = "[F]ile [D]ecrypt" },
	},
}
