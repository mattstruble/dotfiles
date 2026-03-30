local loaded = false
local function ensure_loaded()
    if loaded then return end
    vim.pack.add({ "https://github.com/nvim-mini/mini.files" })

    require("mini.files").setup({
        windows = { preview = true, width_focus = 30, width_preview = 30 },
        options = { use_as_default_explorer = false },
    })

    local show_dotfiles = true
    local filter_show = function() return true end
    local filter_hide = function(fs_entry) return not vim.startswith(fs_entry.name, ".") end

    local toggle_dotfiles = function()
        show_dotfiles = not show_dotfiles
        local new_filter = show_dotfiles and filter_show or filter_hide
        require("mini.files").refresh({ content = { filter = new_filter } })
    end

    local map_split = function(buf_id, lhs, direction, close_on_file)
        local rhs = function()
            local new_target_window
            local cur_target_window = require("mini.files").get_explorer_state().target_window
            if cur_target_window ~= nil then
                vim.api.nvim_win_call(cur_target_window, function()
                    vim.cmd("belowright " .. direction .. " split")
                    new_target_window = vim.api.nvim_get_current_win()
                end)
                require("mini.files").set_target_window(new_target_window)
                require("mini.files").go_in({ close_on_file = close_on_file })
            end
        end
        local desc = "Open in " .. direction .. " split"
        if close_on_file then desc = desc .. " and close" end
        vim.keymap.set("n", lhs, rhs, { buffer = buf_id, desc = desc })
    end

    local files_set_cwd = function()
        local entry = require("mini.files").get_fs_entry()
        if entry == nil then return end
        local cur_directory = vim.fs.dirname(entry.path)
        if cur_directory ~= nil then vim.fn.chdir(cur_directory) end
    end

    vim.api.nvim_create_autocmd("User", {
        pattern = "MiniFilesBufferCreate",
        callback = function(args)
            local buf_id = args.data.buf_id
            vim.keymap.set("n", "g.", toggle_dotfiles, { buffer = buf_id, desc = "Toggle hidden files" })
            vim.keymap.set("n", "gc", files_set_cwd, { buffer = buf_id, desc = "Set cwd" })
            map_split(buf_id, "<C-w>s", "horizontal", false)
            map_split(buf_id, "<C-w>v", "vertical", false)
            map_split(buf_id, "<C-w>S", "horizontal", true)
            map_split(buf_id, "<C-w>V", "vertical", true)
        end,
    })

    vim.api.nvim_create_autocmd("User", {
        pattern = "MiniFilesActionRename",
        callback = function(event)
            Snacks.rename.on_rename_file(event.data.from, event.data.to)
        end,
    })

    loaded = true
end

vim.keymap.set("n", "<leader>fm", function()
    ensure_loaded()
    require("mini.files").open(vim.api.nvim_buf_get_name(0), true)
end, { desc = "Open mini.files (Directory of Current File)" })

vim.keymap.set("n", "<leader>fM", function()
    ensure_loaded()
    require("mini.files").open(vim.uv.cwd(), true)
end, { desc = "Open mini.files (cwd)" })
