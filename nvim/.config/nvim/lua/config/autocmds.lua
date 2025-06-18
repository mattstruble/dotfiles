local A = vim.api
local my_au = A.nvim_create_augroup("mestruble", { clear = true })

-- Highlight on yank
-- https://github.com/aorith/dotfiles/blob/f9069ac4ac165af7429bff0327ef38fee7d723dd/topics/neovim/nvim/lua/aorith/core/autocmds.lua
A.nvim_create_autocmd("TextYankPost", {
    group = my_au,
    callback = function() vim.highlight.on_yank() end,
})

-- Go to the last line before closing the file
-- https://github.com/aorith/dotfiles/blob/f9069ac4ac165af7429bff0327ef38fee7d723dd/topics/neovim/nvim/lua/aorith/core/autocmds.lua
A.nvim_create_autocmd("BufReadPost", {
    group = my_au,
    callback = function(data)
        -- skip some filetypes
        if
            vim.tbl_contains(
                { "minifiles", "minipick", "snacks_picker_input", "gitcommit" },
                vim.bo.filetype
            ) or vim.bo.buftype == "prompt"
        then
            return
        end
        local last_pos = A.nvim_buf_get_mark(data.buf, '"')
        if
            last_pos[1] > 0
            and last_pos[1] <= A.nvim_buf_line_count(data.buf)
        then
            A.nvim_win_set_cursor(0, last_pos)
        end
    end,
})

-- Close some filetypes with <q>
-- https://github.com/aorith/dotfiles/blob/f9069ac4ac165af7429bff0327ef38fee7d723dd/topics/neovim/nvim/lua/aorith/core/autocmds.lua
A.nvim_create_autocmd("FileType", {
    group = my_au,
    pattern = {
        "help",
        "lspinfo",
        "man",
        "notify",
        "qf",
        "spectre_panel",
    },
    callback = function(event)
        vim.bo[event.buf].buflisted = false
        vim.keymap.set(
            "n",
            "q",
            "<cmd>close<cr>",
            { buffer = event.buf, silent = true }
        )
    end,
})

-- Dont format or add comment string on newline
-- https://github.com/aorith/dotfiles/blob/f9069ac4ac165af7429bff0327ef38fee7d723dd/topics/neovim/nvim/lua/aorith/core/autocmds.lua
A.nvim_create_autocmd("FileType", {
    group = my_au,
    callback = function()
        vim.cmd("setlocal formatoptions-=c formatoptions-=r formatoptions-=o")
    end,
    desc = "Ensure proper 'formatoptions'",
})

-- Prefer LSP fold expr over treesitter if it exists
-- https://old.reddit.com/r/neovim/comments/1jmqd7t/sorry_ufo_these_7_lines_replaced_you/mkec07y/?context=2
A.nvim_create_autocmd("LspAttach", {
    group = my_au,
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client:supports_method("textDocument/foldingRange") then
            local win = vim.api.nvim_get_current_win()

            vim.wo[win][0].foldmethod = "expr"
            vim.wo[win][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
        end
    end,
})
A.nvim_create_autocmd("LspDetach", { command = "setl foldexpr<" })

-- Disable virtual text if there is diagnostic in the current line
-- https://old.reddit.com/r/neovim/comments/1jpbc7s/disable_virtual_text_if_there_is_diagnostic_in/
local og_virt_text
local og_virt_line
vim.api.nvim_create_autocmd({ "CursorMoved", "DiagnosticChanged" }, {
    group = my_au,
    callback = function()
        if og_virt_line == nil then
            og_virt_line = vim.diagnostic.config().virtual_lines
        end

        -- ignore if virtual_lines.current_line is disabled
        if not (og_virt_line and og_virt_line.current_line) then
            if og_virt_text then
                vim.diagnostic.config({ virtual_text = og_virt_text })
                og_virt_text = nil
            end
            return
        end

        if og_virt_text == nil then
            og_virt_text = vim.diagnostic.config().virtual_text
        end

        local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1

        if vim.tbl_isempty(vim.diagnostic.get(0, { lnum = lnum })) then
            vim.diagnostic.config({ virtual_text = og_virt_text })
        else
            vim.diagnostic.config({ virtual_text = false })
        end
    end,
})

-- Redraw diagnostics when mode changes
-- https://old.reddit.com/r/neovim/comments/1jpbc7s/disable_virtual_text_if_there_is_diagnostic_in/
vim.api.nvim_create_autocmd("ModeChanged", {
    group = my_au,
    callback = function() pcall(vim.diagnostic.show) end,
})

-- Yank Ring
-- Stores last yanks into the 1,...,9 registers alongside deletes
-- https://old.reddit.com/r/neovim/comments/1jv03t1/simple_yankring/mm9dndu/
local prev_reg0_content = vim.fn.getreg("0")
vim.api.nvim_create_autocmd("TextYankPost", {
    callback = function()
        if vim.v.event.operator == "y" then
            for i = 9, 2, -1 do
                vim.fn.setreg(tostring(i), vim.fn.getreg(tostring(i - 1)))
            end
            vim.fn.setreg("1", prev_reg0_content)
            prev_reg0_content = vim.fn.getreg("0")
        end
    end,
})

-- Set keymap for vim.lsp.buf.rename
A.nvim_create_autocmd("LspAttach", {
    group = my_au,
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        local bufnr = args.buf
        local opts = { noremap = true, silent = true, buffer = bufnr }
        vim.keymap.set(
            "n",
            "<leader>crn",
            vim.lsp.buf.rename,
            { desc = "CR Name", noremap = true, silent = true, buffer = bufnr }
        )
    end,
})
