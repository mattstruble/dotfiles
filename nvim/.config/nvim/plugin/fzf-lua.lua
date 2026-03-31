local loaded = false
local function ensure_loaded()
    if loaded then return end
    loaded = true  -- set before work to prevent retry storms on failure
    local ok, err = pcall(function()
        vim.pack.add({ "https://github.com/ibhagwan/fzf-lua" })
        require("fzf-lua").setup({
            defaults = { hidden = true },
            oldfiles = { cwd_only = true, stat_file = true, include_current_session = true },
            previewers = { builtin = { syntax_limit_b = 1024 * 100 } },
        })
    end)
    if not ok then
        vim.notify("fzf-lua: " .. tostring(err), vim.log.levels.ERROR)
    end
end

local map = vim.keymap.set
map("n", "<leader>fb", function()
    ensure_loaded()
    require("fzf-lua").buffers({ sort_mru = true, sort_lastused = true })
end, { desc = "Buffers" })
map("n", '<leader>s"', function() ensure_loaded(); require("fzf-lua").registers() end, { desc = "Registers" })
map("n", "<leader>sa", function() ensure_loaded(); require("fzf-lua").autocmds() end, { desc = "Auto Commands" })
map("n", "<leader>sc", function() ensure_loaded(); require("fzf-lua").command_history() end, { desc = "Command History" })
map("n", "<leader>sC", function() ensure_loaded(); require("fzf-lua").commands() end, { desc = "Commands" })
map("n", "<leader>sd", function() ensure_loaded(); require("fzf-lua").diagnostics_document() end, { desc = "Document Diagnostics" })
map("n", "<leader>sD", function() ensure_loaded(); require("fzf-lua").diagnostics_workspace() end, { desc = "Workspace Diagnostics" })
map("n", "<leader>sh", function() ensure_loaded(); require("fzf-lua").helptags() end, { desc = "Help Tags" })
map("n", "<leader>sk", function() ensure_loaded(); require("fzf-lua").keymaps() end, { desc = "Keymaps" })
map("n", "<leader>sm", function() ensure_loaded(); require("fzf-lua").marks() end, { desc = "Marks" })
map("n", "<leader>sR", function() ensure_loaded(); require("fzf-lua").resume() end, { desc = "Resume Last Search" })
map("n", "<leader>ss", function() ensure_loaded(); require("fzf-lua").lsp_document_symbols() end, { desc = "Document Symbols" })
map("n", "<leader>sS", function() ensure_loaded(); require("fzf-lua").lsp_workspace_symbols() end, { desc = "Workspace Symbols" })
map("n", "<leader>gc", function() ensure_loaded(); require("fzf-lua").git_commits() end, { desc = "Git Commits" })
map("n", "<leader>gs", function() ensure_loaded(); require("fzf-lua").git_status() end, { desc = "Git Status" })
