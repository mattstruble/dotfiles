return {
    "ibhagwan/fzf-lua",
    cmd = "FzfLua",
    keys = {
        -- find
        { "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Find Files" },
        { "<leader>fg", "<cmd>FzfLua live_grep<cr>", desc = "Live Grep" },
        { "<leader>fb", "<cmd>FzfLua buffers sort_mru=true sort_lastused=true<cr>", desc = "Buffers" },
        { "<leader>fr", "<cmd>FzfLua oldfiles<cr>", desc = "Recent Files" },
        { "<leader>fc", function() require("fzf-lua").files({ cwd = vim.fn.stdpath("config") }) end, desc = "Find Config File" },
        -- search
        { "<leader>sg", "<cmd>FzfLua live_grep<cr>", desc = "Grep" },
        { "<leader>sw", "<cmd>FzfLua grep_cword<cr>", desc = "Grep Word (cword)" },
        { "<leader>sW", "<cmd>FzfLua grep_cWORD<cr>", desc = "Grep Word (cWORD)" },
        { "<leader>sw", "<cmd>FzfLua grep_visual<cr>", mode = "v", desc = "Grep Selection" },
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
