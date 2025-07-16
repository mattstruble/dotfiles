return {
    "olimorris/persisted.nvim", -- Session management
    event = "BufReadPre",
    opts = {
        save_dir = SessionDir .. "/",
        use_git_branch = true,
        autosave = true,
        should_save = function()
            local excluded_filetypes = {
                "alpha",
                "oil",
                "lazy",
                "",
            }

            for _, filetype in ipairs(excluded_filetypes) do
                if vim.bo.filetype == filetype then return false end
            end

            return true
        end,
    },
    init = function()
        vim.api.nvim_create_user_command(
            "Sessions",
            function() require("persisted").select() end,
            { desc = "List Sessions" }
        )
    end,
}
