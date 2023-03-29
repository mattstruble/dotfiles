--------------------------
-- CODE RUNNER
--------------------------

return {
	"CRAG666/code_runner.nvim",
	config = function()
		vim.keymap.set("n", "<leader>r", ":RunCode<CR>", { noremap = true, silent = false })
		vim.keymap.set("n", "<leader>rf", ":RunFile<CR>", { noremap = true, silent = false })
		vim.keymap.set("n", "<leader>rft", ":RunFile tab<CR>", { noremap = true, silent = false })
		vim.keymap.set("n", "<leader>rp", ":RunProject<CR>", { noremap = true, silent = false })
		vim.keymap.set("n", "<leader>rc", ":RunClose<CR>", { noremap = true, silent = false })
		vim.keymap.set("n", "<leader>crf", ":CRFiletype<CR>", { noremap = true, silent = false })
		vim.keymap.set("n", "<leader>crp", ":CRProjects<CR>", { noremap = true, silent = false })

		require("code_runner").setup({
			mode = "toggleterm",
			filetype = {
				python = "python $fileName",
				lua = "lua $fileName",
				c = "cd . && gcc $fileName -o $fileNameWithoutExt && $dir\\$fileNameWithoutExt",
				cpp = "cd . && g++ $fileName -o $fileNameWithoutExt && $dir\\$fileNameWithoutExt",
			},
			term = {
				position = "bot",
				size = 20,
			},
		})
	end,
}
