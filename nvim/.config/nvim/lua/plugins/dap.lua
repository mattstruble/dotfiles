--------------------------
-- DAP
--------------------------

return {
	{
		"rcarriga/nvim-dap-ui",
		opts = {
			controls = {
				element = "repl",
				enabled = true,
				icons = {
					disconnect = " ",
					pause = " ",
					play = " ",
					run_last = " ",
					step_back = " ",
					step_into = " ",
					step_out = " ",
					step_over = " ",
					terminate = " ",
				},
			},
			layouts = {
				{
					elements = {
						{ id = "scopes", size = 0.25 },
						{ id = "breakpoints", size = 0.25 },
						{ id = "stacks", size = 0.25 },
						{ id = "watches", size = 0.25 },
					},
					size = 40,
					position = "right",
				},
				{
					elements = {
						{ id = "repl", size = 0.5 },
						{ id = "console", size = 0.5 },
					},
					size = 10,
					position = "bottom",
				},
			},
		},
	},
}
