--------------------------
-- DAP
--------------------------

return {
	"mfussenegger/nvim-dap",
	dependencies = {
		"theHamsta/nvim-dap-virtual-text",
		"rcarriga/nvim-dap-ui",
		"mfussenegger/nvim-dap-python",
		"nvim-telescope/telescope-dap.nvim",
	},
	config = function()
		local dap = require("dap")
		local dapui = require("dapui")
		local opts = { noremap = true, silent = true }

		-- additional setups
		require("nvim-dap-virtual-text").setup()
		dapui.setup({
			sidebar = {
				position = "right",
			},
		})

		dap.listeners.after.event_initialized["dapui_config"] = function()
			dapui.open(1)
		end

		dap.listeners.before.event_terminated["dapui_config"] = function()
			dapui.close(1)
		end

		dap.listeners.before.event_exited["dapui_config"] = function()
			dapui.close(1)
		end

		-- Configurations
		require("dap-python").setup("~/.virtualenvs/debugpy/bin/python")

		table.insert(dap.configurations.python, {
			type = "python",
			request = "launch",
			name = "Python launch configuration",
			program = "${file}",
			justMyCode = false,
			-- ... more options, see https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings
		})

		-- keybindings
		vim.keymap.set("n", "<F5>", dap.continue, opts)
		vim.keymap.set("n", "<F9>", dap.step_back, opts)
		vim.keymap.set("n", "<F10>", dap.step_over, opts)
		vim.keymap.set("n", "<F11>", dap.step_into, opts)
		vim.keymap.set("n", "<F12>", dap.step_out, opts)

		vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint, opts)
		vim.keymap.set("n", "<leader>B", function()
			dap.set_breakpoint(vim.fn.input("Breakpoint condition"))
		end, opts)
		vim.keymap.set("n", "<c-b>", dap.clear_breakpoints, opts)

		vim.keymap.set("n", "<leader>lp", function()
			dap.set_breakpoint(nil, nil, vim.fn.input("Log point message"))
		end, opts)

		vim.keymap.set("n", "<leader>dr", dap.repl.open, opts)
		vim.keymap.set("n", "<leader>dc", dap.run_to_cursor, opts)
		vim.keymap.set("n", "<leader>dl", dap.run_last, opts)
		vim.keymap.set("n", "<leader>ddt", dap.terminate, opts)
	end,
}
