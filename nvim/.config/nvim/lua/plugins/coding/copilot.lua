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
        opts = {
            suggestion = {
                enabled = true,
                auto_trigger = true,
                hide_during_completion = true,
                debounce = 75,
                keymap = {
                    accept = "<Tab>",
                    next = "<C-n>",
                    prev = "<C-p>",
                    dismiss = "<C-x>",
                },
            },
            panel = { enabled = false },
            filetypes = {
                markdown = true,
                help = false,
                gitcommit = true,
                gitrebase = false,
                opencode = false,
                opencode_output = false,
                ["."] = false,
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
        config = function()
            require("supermaven-nvim").setup({
                keymaps = {
                    accept_suggestion = "<Tab>",
                    clear_suggestion = "<C-x>",
                    accept_word = "<C-l>",
                },
                ignore_filetypes = {
                    opencode = true,
                    opencode_output = true,
                    help = true,
                    gitrebase = true,
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
