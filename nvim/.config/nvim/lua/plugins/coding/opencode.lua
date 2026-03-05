return {
    {
        "sudo-tee/opencode.nvim",
        config = function()
            -- Set AWS_PROFILE for Bedrock authentication
            vim.env.AWS_PROFILE = "bedrock"

            require("opencode").setup({
                preferred_picker = "snacks",
                preferred_completion = "blink",
                default_global_keymaps = true,
                default_mode = "plan",
                keymap_prefix = "<leader>o",
                keymap = {
                    editor = {
                        ["<leader>og"] = { "toggle" },
                        ["<leader>oi"] = { "open_input" },
                        ["<leader>oI"] = { "open_input_new_session" },
                        ["<leader>oo"] = { "open_output" },
                        ["<leader>ot"] = { "toggle_focus" },
                        ["<leader>oq"] = { "close" },
                        ["<leader>os"] = { "select_session" },
                        ["<leader>op"] = { "configure_provider" },
                        ["<leader>od"] = { "diff_open" },
                        ["<leader>o]"] = { "diff_next" },
                        ["<leader>o["] = { "diff_prev" },
                        ["<leader>oc"] = { "diff_close" },
                        ["<leader>o/"] = { "quick_chat", mode = { "n", "x" } },
                    },
                    input_window = {
                        ["<cr>"] = { "submit_input_prompt", mode = { "n", "i" } },
                        ["<esc>"] = { "close" },
                        ["<C-c>"] = { "cancel" },
                        ["~"] = { "mention_file", mode = "i" },
                        ["@"] = { "mention", mode = "i" },
                        ["/"] = { "slash_commands", mode = "i" },
                        ["#"] = { "context_items", mode = "i" },
                        ["<C-i>"] = { "focus_input", mode = { "n", "i" } },
                        ["<tab>"] = { "toggle_pane", mode = { "n", "i" } },
                        ["<up>"] = { "prev_prompt_history", mode = { "n", "i" } },
                        ["<down>"] = { "next_prompt_history", mode = { "n", "i" } },
                    },
                    output_window = {
                        ["<esc>"] = { "close" },
                        ["<C-c>"] = { "cancel" },
                        ["]]"] = { "next_message" },
                        ["[["] = { "prev_message" },
                        ["<tab>"] = { "toggle_pane", mode = { "n", "i" } },
                        ["i"] = { "focus_input", "n" },
                    },
                },
                ui = {
                    position = "right",
                    window_width = 0.40,
                },
            })
        end,
        dependencies = {
            "nvim-lua/plenary.nvim",
            {
                "MeanderingProgrammer/render-markdown.nvim",
                opts = {
                    anti_conceal = { enabled = false },
                    file_types = { "markdown", "opencode_output" },
                },
                ft = { "markdown", "opencode_output" },
            },
        },
    },
    {
        "jellydn/99",
        branch = "feature/blink-cmp",
        dependencies = {
            "Saghen/blink.compat",
        },
        config = function()
            local _99 = require("99")
            local cwd = vim.uv.cwd()

            local basename = vim.fs.basename(cwd)

            _99.setup({
                logger = {
                    level = _99.INFO,
                    path = "/tmp/" .. basename .. ".99.debug",
                    print_on_error = true,
                },

                completion = {
                    source = "blink",
                },

                md_files = {
                    "AGENT.md",
                    "AGENTS.md",
                },
            })

            vim.keymap.set("v", "<leader>9v", function()
                _99.visual()
            end, { desc = "99 visual fill." })

            vim.keymap.set("v", "<leader>9s", function()
                _99.stop_all_requests()
            end, { desc = "99 kill all requests." })
        end,
    },
}
