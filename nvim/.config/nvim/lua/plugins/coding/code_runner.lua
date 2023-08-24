--------------------------
-- CODE RUNNER
--------------------------

return {
	"CRAG666/code_runner.nvim",
	lazy = true,
	config = function()
		require("code_runner").setup({
			mode = "toggleterm",
			filetype = {
				python = "python $dir/$fileName",
				lua = "lua $dir/$fileName",
				c = "cd . && gcc $fileName -o $fileNameWithoutExt && $dir\\$fileNameWithoutExt",
				cpp = "cd . && g++ $fileName -o $fileNameWithoutExt && $dir\\$fileNameWithoutExt",
			},
			term = {
				position = "bot",
				size = 20,
			},
		})
	end,
	keys = {
		{ "<leader>rc", ":RunCode<cr>", desc = "Run Code" },
		{ "<leader>rf", ":RunFile<cr>", desc = "Run File" },
		{ "<leader>rft", ":RunFile tab<cr>", desc = "Run File Tab" },
		{ "<leader>rp", ":RunProject<cr>", desc = "Run Project" },
		{ "<leader>rC", ":RunClose<cr>", desc = "Run Close" },
		{ "<leader>crf", ":CRFiletype<cr>", desc = "CR File Type" },
		{ "<leader>crp", ":CRProjects<cr>", desc = "CR Projects" },
	},
}
