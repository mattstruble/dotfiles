return {
	"echasnovski/mini.nvim",
	config = function()
		local goose = [[


⡏⠙⠻⢦⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⠶⠟⠛⠿⠗⣦⣄⠀⠀⠀⠀
⡇⠀⠀⠀⠀⠙⠦⣄⠀⠀⠀⠀⠀⠀⠀⢀⣴⠋⠀⠀⠀⠀⠀⠀⠀⠉⢧⡀⠀⠀
⠙⢄⠀⠀⠀⠀⠀⠙⠲⢦⣀⠀⠀⠀⠀⣸⠋⠀⠀⠀⢠⣤⠀⠀⠀⠀⠘⢳⡀⠀
⠀⠈⠳⣀⠀⠀⠀⠀⠀⠀⠉⠻⢦⣤⣼⠴⠖⠒⣄⠀⠈⠉⠀⠀⠀⠀⠀⠈⣵⠀
⠀⠀⠀⠈⠳⣄⠀⠀⠀⠀⠀⠀⢀⣿⠋⠀⠀⠀⠈⢆⠀⠀⠀⠀⠀⠀⠀⠀⠀⢣
⠀⠀⠀⠀⠀⠈⠳⢦⡀⠀⠀⠀⣸⠁⠀⠀⠀⠀⣠⣼⣷⡤⢤⣄⠀⠀⠀⠀⠀⣻
⠀⠀⠀⠀⠀⠀⠀⠀⠙⢦⣤⣴⠋⠀⠀⠀⢀⣴⣿⣿⢿⠁⢘⣻⠀⠀⠀⠀⠀⣿
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠻⣔⣢⣲⣼⡿⣿⣿⠟⠁⠀⢸⠾⠀⠀⠀⠀⠀⢸
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠫⣿⠋⠀⠀⠀⣾⡇⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⠇⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⡏⠀⠀⠀⠀⠀⠀⠀


]]
		local toaster = [[


⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣄⠀⠀⠀⢀⡀⠀⠀⠀⣀⡀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⣟⠁⠀⠀⣴⡏⠁⠀⠀⣾⡋⠁⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠿⠄⠀⠈⠻⠷⠀⠀⠈⢹⣷⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣤⣤⣤⣤⣤⣤⣤⣤⣀⠀⠠⣤⣀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠰⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⣹⣿⡿⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠛⠛⠀⠛⠛⠛⠛⠉⠛⠛⠛⠀⠐⠛⠛⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⣠⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣦⠀⠀⠀
⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀
⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀
⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠿⠛⠛⠿⣿⡇⠀⠀
⠀⠀⠀⠀⠀⠀⠸⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠏⢠⣾⣿⣦⠘⠇⠀⠀
⠀⠀⢀⣤⡀⠀⢰⣶⣶⣶⣶⣶⣶⣶⣶⣶⣶⣶⣶⣶⣶⣆⠘⢿⣿⠟⢠⡆⠀⠀
⠀⠀⠘⠛⠛⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣤⣤⣶⣿⡇⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⢠⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣄⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠘⠛⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⠛⠀⠀⠀⠀


        ]]
		require("mini.starter").setup({
			items = { { name = "", action = "", section = "" } },
			header = toaster,
			footer = "",
			silent = true,
			content_hooks = {
				require("mini.starter").gen_hook.aligning("center", "top"),
			},
		})
	end,
}