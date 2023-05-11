--------------------------
-- TOGGLETERM
--------------------------

-- as seen in "init.lua," here is the Vim way:
-- vim.cmd('autocmd! TermOpen term://* lua set_terminal_keymaps()')

-- ...and the way you do it in Lua:

return {
	"akinsho/toggleterm.nvim",
	version = "*",
	config = function()
		local opts = { noremap = true, silent = true }

		require("toggleterm").setup({
			size = 10,
			open_mapping = [[<c-\>]],
			hide_numbers = true,
			shade_filetypes = {},
			shade_terminals = false,
			insert_mappings = true,
			start_in_insert = true,
			autochdir = true,
			persist_size = true,
			close_on_exit = true,
			shell = vim.o.shell,
			direction = "float",
			highlights = {
				NormalFloat = {
					link = "Normal",
				},
				FloatBorder = {
					link = "FloatBorder",
				},
				float_opts = {
					border = "rounded",
					winblend = 0,
				},
			},
		})

		local Terminal = require("toggleterm.terminal").Terminal
		local python = Terminal:new({ cmd = "python", direction = "float", hidden = true })
		local lua = Terminal:new({ cmd = "lua", direction = "horizontal", hidden = true })

		function _PYTHON_TOGGLE()
			python:toggle()
		end

		function _LUA_TOGGLE()
			lua:toggle()
		end

		vim.keymap.set("n", "<leader>tp", "<cmd>lua _PYTHON_TOGGLE()<CR>", opts)
		vim.keymap.set("n", "<leader>tl", "<cmd>lua _LUA_TOGGLE()<CR>", opts)
	end,
}
