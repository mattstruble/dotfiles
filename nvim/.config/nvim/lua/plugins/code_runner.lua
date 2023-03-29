--------------------------
-- CODE RUNNER
--------------------------

return {
	"CRAG666/code_runner.nvim",
	config = function()
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
