--------------------------
-- TELESCOPE
--------------------------
return {
	{
		"nvim-telescope/telescope-fzf-native.nvim",
		enabled = false,
		lazy = true,
		build = "make",
		name = "telescope-fzf",
	},
	{
		"nvim-telescope/telescope-frecency.nvim",
		enabled = false,
		lazy = true,
		enabled = false,
		dependencies = { "kkharji/sqlite.lua" },
		config = function()
			require("telescope").load_extension("frecency")
		end,
	},

	{
		"prochri/telescope-all-recent.nvim",
		enabled = false,
		lazy = true,
		dependencies = { "kkharji/sqlite.lua" },
		opts = {
			default = {
				disable = true, -- disable any unknown pickers
				use_cwd = true, -- differentiate scoring based on cwd
				sorting = "frecency",
			},
		},
	},
	{
		"ahmedkhalf/project.nvim",
		enabled = false,

		dependencies = {
			"nvim-telescope/telescope.nvim",
		},
		event = "VeryLazy",
		opts = {},
		config = function(_, opts)
			require("project_nvim").setup(opts)
			require("telescope").load_extension("projects")
		end,
		keys = {
			{ "<leader>sp", "<cmd>Telescope projects<cr>", desc = "[S]earch [P]rojects" },
		},
	},
	{
		"nvim-telescope/telescope.nvim",
		enabled = false,

		dependencies = {
			"nvim-lua/plenary.nvim",
			"telescope-fzf",
			"nvim-telescope/telescope-ui-select.nvim",
			-- "nvim-telescope/telescope-frecency.nvim",
			"prochri/telescope-all-recent.nvim",
		},
		keys = {
			{ "<leader>sf", "<cmd>Telescope find_files hidden=true no_ignore=true<cr>", desc = "[S]earch [F]iles" },
			{ "<leader>sg", "<cmd>Telescope live_grep<cr>", desc = "[S]earch by [G]rep" },
			{
				"<leader>ss",
				"<cmd>Telescope grep_string<cr>",
				desc = "[S]earch current [S]tring",
			},
			{ "<leader>sb", "<cmd>Telescope buffers<cr>", desc = "[S]earch [B]buffers" },
			{ "<leader>sh", "<cmd>Telescope help_tags<cr>", desc = "[S]earch [H]elp" },
			{
				"<leader>sd",
				"<cmd>Telescope diagnostics<cr>",
				desc = "[S]earch [D]iagnostics",
			},
		},
		config = function()
			local plenary = require("plenary.path")
			local actions = require("telescope.actions")
			local themes = require("telescope.themes")
			local builtin = require("telescope.builtin")

			local dropdown = themes.get_dropdown({
				hidden = true,
				no_ignore = true,
				previewer = false,
				prompt_title = "",
				preview_title = "",
				results_title = "",
				layout_config = { prompt_position = "top" },
			})

			local with_title = function(opts, extra)
				extra = extra or {}
				local path = opts.cwd or opts.path or extra.cwd or extra.path or nil
				local title = ""
				local buf_path = vim.fn.expand("%:p:h")
				local cwd = vim.fn.getcwd()
				if path ~= nil and buf_path ~= cwd then
					title = plenary:new(buf_path):make_relative(cwd)
				else
					title = vim.fn.fnamemodify(cwd, ":t")
				end

				return vim.tbl_extend("force", opts, {
					prompt_title = title,
				})
			end

			vim.api.nvim_create_augroup("startup", { clear = true })
			vim.api.nvim_create_autocmd("VimEnter", {
				group = "startup",
				pattern = "*",
				callback = function()
					-- open file browser if arg is in a folder
					local arg = vim.api.nvim_eval("argv(0)")
					if arg and (vim.fn.isdirectory(arg) ~= 0 or arg == "") then
						vim.defer_fn(function()
							builtin.find_files(with_title(dropdown))
						end, 10)
					end
				end,
			})

			require("telescope").setup({
				defaults = {
					prompt_prefix = "❯ ",
					prompt_title = "",
					results_title = "",
					preview_title = "",
					selection_caret = "❯ ",
					multi_icon = "+ ",
					sorting_strategy = "ascending",
					layout_strategy = "flex",
					layout_config = {
						horizontal = {
							prompt_position = "top",
							preview_width = 0.55,
						},
						vertical = {
							mirror = false,
						},
						width = 0.85,
						height = 0.80,
					},
					-- path_display = { "truncate" },
					{
						i = {
							["<C-n>"] = actions.cycle_history_next,
							["<C-p>"] = actions.cycle_history_prev,

							["<C-j>"] = actions.move_selection_next,
							["<C-k>"] = actions.move_selection_previous,

							["<C-c>"] = actions.close,

							["<Down>"] = actions.move_selection_next,
							["<Up>"] = actions.move_selection_previous,

							["<CR>"] = actions.select_default,
							["<C-x>"] = actions.select_horizontal,
							["<C-v>"] = actions.select_vertical,
							["<C-t>"] = actions.select_tab,

							["<C-u>"] = actions.preview_scrolling_up,
							["<C-d>"] = actions.preview_scrolling_down,

							["<PageUp>"] = actions.results_scrolling_up,
							["<PageDown>"] = actions.results_scrolling_down,

							["<Tab>"] = actions.toggle_selection + actions.move_selection_worse,
							["<S-Tab>"] = actions.toggle_selection + actions.move_selection_better,
							["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
							["<M-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
							["<C-l>"] = actions.complete_tag,
							["<C-_>"] = actions.which_key, -- keys from pressing <C-/>
						},
						n = {
							["<esc>"] = actions.close,
							["<CR>"] = actions.select_default,
							["<C-x>"] = actions.select_horizontal,
							["<C-v>"] = actions.select_vertical,
							["<C-t>"] = actions.select_tab,

							["<Tab>"] = actions.toggle_selection + actions.move_selection_worse,
							["<S-Tab>"] = actions.toggle_selection + actions.move_selection_better,
							["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
							["<M-q>"] = actions.send_selected_to_qflist + actions.open_qflist,

							["j"] = actions.move_selection_next,
							["k"] = actions.move_selection_previous,
							["H"] = actions.move_to_top,
							["M"] = actions.move_to_middle,
							["L"] = actions.move_to_bottom,

							["<Down>"] = actions.move_selection_next,
							["<Up>"] = actions.move_selection_previous,
							["gg"] = actions.move_to_top,
							["G"] = actions.move_to_bottom,

							["<C-u>"] = actions.preview_scrolling_up,
							["<C-d>"] = actions.preview_scrolling_down,

							["<PageUp>"] = actions.results_scrolling_up,
							["<PageDown>"] = actions.results_scrolling_down,

							["?"] = actions.which_key,
						},
					},
					file_ignore_patterns = {
						"^.git/*",
						"node_modules/*",
						"^build/*",
						"dist/*",
						"*.lock",
						".venv/*",
						"^.*cache/*",
						".direnv/*",
					},
					vimgrep_arguments = {
						"rg",
						"--color=never",
						"--no-heading",
						"--with-filename",
						"--line-number",
						"--column",
						"--smart-case",
						"--no-ignore",
						"--hidden",
					},
				},
				extensions = {
					["ui-select"] = {
						themes.get_dropdown({}),
					},
					project = {
						base_dirs = {
							{ path = "~/Software", max_depth = 4 },
						},
						hidden_files = true, -- default: false
						theme = "dropdown",
						order_by = "asc",
						search_by = "title",
						sync_with_nvim_tree = true, -- default false
						-- default for on_project_selected = find project files
						on_project_selected = function(prompt_bufnr)
							-- Do anything you want in here. For example:
							project_actions.change_working_directory(prompt_bufnr, false)
							require("harpoon.ui").nav_file(1)
						end,
					},
					--[[ frecency = {
						show_scores = false,
						show_unindexed = true,
						disable_devicons = false,
						ignore_patterns = {
							"*.git/*",
							"*/build/*",
							"*/dist/*",
							"*.lock",
							"*.venv/*",
							"*cache/*",
						},
					}, ]]
				},
			})
			require("telescope").load_extension("fzf")
			require("telescope").load_extension("ui-select")
		end,
	},
}
