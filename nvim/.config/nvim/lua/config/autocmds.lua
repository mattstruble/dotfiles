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
        if vim.tbl_contains({ "minifiles", "minipick", "snacks_picker_input", "gitcommit" }, vim.bo.filetype) or vim.bo.buftype == "prompt" then return end
        local last_pos = A.nvim_buf_get_mark(data.buf, '"')
        if last_pos[1] > 0 and last_pos[1] <= A.nvim_buf_line_count(data.buf) then A.nvim_win_set_cursor(0, last_pos) end
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
        vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
    end,
})

-- Dont format or add comment string on newline
-- https://github.com/aorith/dotfiles/blob/f9069ac4ac165af7429bff0327ef38fee7d723dd/topics/neovim/nvim/lua/aorith/core/autocmds.lua
A.nvim_create_autocmd("FileType", {
    group = my_au,
    callback = function() vim.cmd("setlocal formatoptions-=c formatoptions-=r formatoptions-=o") end,
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
