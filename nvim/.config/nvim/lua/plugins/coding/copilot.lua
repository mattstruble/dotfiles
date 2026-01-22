-- Helper function to check if Copilot is authenticated
local function has_copilot_auth()
    local auth_file = vim.fn.expand("~/.config/github-copilot/apps.json")
    return vim.fn.filereadable(auth_file) == 1
end

return {
    -- GitHub Copilot: Only loads if authenticated
    {
        "zbirenbaum/copilot.lua",
        cmd = "Copilot",
        event = "InsertEnter",
        cond = has_copilot_auth,
        keys = {
            {
                "<leader>cp",
                function()
                    vim.cmd("Copilot toggle")
                    local attached = require("copilot.client").buf_is_attached(0)
                    vim.notify(
                        attached and "Copilot enabled" or "Copilot disabled",
                        vim.log.levels.INFO
                    )
                end,
                desc = "Toggle Copilot",
            },
        },
        opts = {
            logger = {
                file_log_level = vim.log.levels.ERROR,
                print_log_level = vim.log.levels.ERROR,
            },
            suggestion = {
                enabled = true,
                auto_trigger = true,
                hide_during_completion = true,
                debounce = 75,
                keymap = {
                    accept = false, -- Handled by blink.cmp Super-Tab
                    next = false,   -- Handled by blink.cmp Super C-n
                    prev = false,   -- Handled by blink.cmp Super C-p
                    dismiss = "<C-x>",
                },
            },
            panel = { enabled = false },
            filetypes = {
                ["*"] = true,
                help = false,
                gitcommit = false,
                gitrebase = false,
                opencode = false,
                opencode_output = false,
                snacks_input = false,
            },
        },
    },

    -- Supermaven: Free fallback when Copilot is not authenticated
    {
        "supermaven-inc/supermaven-nvim",
        event = "InsertEnter",
        cond = function()
            return not has_copilot_auth()
        end,
        keys = {
            {
                "<leader>cp",
                function()
                    local api = require("supermaven-nvim.api")
                    api.toggle()
                    vim.notify(
                        api.is_running() and "Supermaven enabled" or "Supermaven disabled",
                        vim.log.levels.INFO
                    )
                end,
                desc = "Toggle Supermaven",
            },
        },
        config = function()
            require("supermaven-nvim").setup({
                log_level = "error",
                keymaps = {
                    accept_suggestion = false, -- Handled by blink.cmp Super-Tab
                    clear_suggestion = "<C-x>",
                    accept_word = "<C-l>",
                },
                ignore_filetypes = {
                    opencode = true,
                    opencode_output = true,
                    help = true,
                    gitrebase = true,
                    gitcommit = true,
                    snacks_input = true,
                },
                disable_inline_completion = false,
                disable_keymaps = false,
            })

            -- Automatically use free tier
            vim.defer_fn(function()
                local api = require("supermaven-nvim.api")
                if not api.is_running() then
                    api.use_free_version()
                end
            end, 100)
        end,
    },
}
