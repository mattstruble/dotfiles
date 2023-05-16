--------------------------
-- DAP
--------------------------

return {
	{
		"rcarriga/nvim-dap-ui",
		lazy = true,
		dependencies = "mortepau/codicons.nvim",
		keys = {
			{
				"<leader>du",
				function()
					require("dapui").toggle({})
				end,
				desc = "Dap UI",
			},
			{
				"<leader>de",
				function()
					require("dapui").eval()
				end,
				desc = "Dap Eval",
				mode = { "n", "v" },
			},
		},
		config = function()
			local dap = require("dap")
			local dapui = require("dapui")

			dapui.setup({
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
			})

			dap.listeners.after.event_initialized["dapui_config"] = function()
				dapui.open()
			end

			dap.listeners.before.event_terminated["dapui_config"] = function()
				dapui.close()
			end

			dap.listeners.before.event_exited["dapui_config"] = function()
				dapui.close()
			end
		end,
	},
	{
		"mfussenegger/nvim-dap-python",
		lazy = true,
		config = function()
			local adapter_python_path = require("plugins.dap.adapters").debugpy.path
			local py = require("mestruble.lang.python")
			require("dap-python").setup(adapter_python_path)
			require("dap-python").resolve_python = function()
				py.env(vim.fn.getcwd())
				return py.pep582(vim.fn.getcwd())
			end
		end,
	},
	{
		"theHamsta/nvim-dap-virtual-text",
		lazy = true,
		config = function()
			require("nvim-dap-virtual-text").setup({})
		end,
	},
	{
		"mfussenegger/nvim-dap",
		lazy = true,
		dependencies = {
			"theHamsta/nvim-dap-virtual-text",
			"rcarriga/nvim-dap-ui",
			"mfussenegger/nvim-dap-python",
			"nvim-telescope/telescope-dap.nvim",
		},
		config = function()
			vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })
			vim.fn.sign_define(
				"DapStopped",
				{ text = "󰧂 ", texthl = "DiagnosticWarn", linehl = "DapStoppedLine", numhl = "" }
			)
			vim.fn.sign_define("DapBreakpoint", { text = " ", texthl = "DiagnosticError", linehl = "", numhl = "" })
			vim.fn.sign_define(
				"DapBreakpointCondition",
				{ text = " ", texthl = "DiagnosticError", linehl = "", numhl = "" }
			)
			vim.fn.sign_define(
				"DapBreakpointRejected",
				{ text = " ", texthl = "DiagnosticWarn", linehl = "", numhl = "" }
			)
			vim.fn.sign_define("DapLogPoint", { text = " ", texthl = "DiagnosticInfo", linehl = "", numhl = "" })
		end,
        -- stylua: ignore
        keys = {
            { "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, desc = "Breakpoint Condition" },
            { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
            { "<leader>dc", function() require("dap").continue() end, desc = "Continue" },
            { "<leader>dl", function() require("dap").set_breakpoint(nil, nil, vim.fn.input('Log point message: ')) end, desc = "Set Log Point" },
            { "<leader>dC", function() require("dap").run_to_cursor() end, desc = "Run to Cursor" },
            { "<leader>dg", function() require("dap").goto_() end, desc = "Go to line (no execute)" },
            { "<leader>di", function() require("dap").step_into() end, desc = "Step Into" },
            { "<leader>dj", function() require("dap").down() end, desc = "Down" },
            { "<leader>dk", function() require("dap").up() end, desc = "Up" },
            { "<leader>dO", function() require("dap").step_out() end, desc = "Step Out" },
            { "<leader>do", function() require("dap").step_over() end, desc = "Step Over" },
            { "<leader>dp", function() require("dap").pause() end, desc = "Pause" },
            { "<leader>dr", function() require("dap").repl.toggle() end, desc = "Toggle REPL" },
            { "<leader>ds", function() require("dap").session() end, desc = "Session" },
            { "<leader>dt", function() require("dap").terminate() end, desc = "Terminate" },
            { "<leader>dw", function() require("dap.ui.widgets").hover() end, desc = "Widgets" },
            { "<leader>dR", function() require("dap").clear_breakpoints() end, desc = "Removes all breakpoints" },
        },
	},
}
