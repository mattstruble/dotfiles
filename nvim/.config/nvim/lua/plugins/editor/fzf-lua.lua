return {
    "ibhagwan/fzf-lua",
    cmd = "FzfLua",
    keys = {
        -- find
        { "<leader>fb", "<cmd>FzfLua buffers sort_mru=true sort_lastused=true<cr>", desc = "Buffers" },
        -- search
        { '<leader>s"', "<cmd>FzfLua registers<cr>", desc = "Registers" },
        { "<leader>sa", "<cmd>FzfLua autocmds<cr>", desc = "Auto Commands" },
        { "<leader>sc", "<cmd>FzfLua command_history<cr>", desc = "Command History" },
        { "<leader>sC", "<cmd>FzfLua commands<cr>", desc = "Commands" },
        { "<leader>sd", "<cmd>FzfLua diagnostics_document<cr>", desc = "Document Diagnostics" },
        { "<leader>sD", "<cmd>FzfLua diagnostics_workspace<cr>", desc = "Workspace Diagnostics" },
        { "<leader>sh", "<cmd>FzfLua helptags<cr>", desc = "Help Tags" },
        { "<leader>sk", "<cmd>FzfLua keymaps<cr>", desc = "Keymaps" },
        { "<leader>sm", "<cmd>FzfLua marks<cr>", desc = "Marks" },
        { "<leader>sR", "<cmd>FzfLua resume<cr>", desc = "Resume Last Search" },
        { "<leader>ss", "<cmd>FzfLua lsp_document_symbols<cr>", desc = "Document Symbols" },
        { "<leader>sS", "<cmd>FzfLua lsp_workspace_symbols<cr>", desc = "Workspace Symbols" },
        -- git
        { "<leader>gc", "<cmd>FzfLua git_commits<cr>", desc = "Git Commits" },
        { "<leader>gs", "<cmd>FzfLua git_status<cr>", desc = "Git Status" },
    },
    opts = {
        defaults = {
            hidden = true,
        },
        oldfiles = {
            cwd_only = true,
            stat_file = true, -- verify files exist on disk
            include_current_session = true,
        },
        previewers = {
            builtin = {
                syntax_limit_b = 1024 * 100,
            },
        },
    },
}
