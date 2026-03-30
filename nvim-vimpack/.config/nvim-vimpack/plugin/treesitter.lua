local ensure_installed = {
    "bash", "c", "gitcommit", "helm", "html", "javascript", "jsdoc",
    "json", "lua", "luadoc", "luap", "markdown", "markdown_inline",
    "python", "query", "regex", "tsx", "typescript", "vim", "vimdoc", "yaml",
}

-- Eager: treesitter core + extensions
vim.pack.add({
    "https://gitlab.com/HiPhish/rainbow-delimiters.nvim",
    "https://github.com/nvim-treesitter/nvim-treesitter-context",
    { src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects", version = "main" },
    "https://github.com/nvim-treesitter/nvim-treesitter",
    "https://github.com/windwp/nvim-ts-autotag",
})

-- Install desired parsers
require("nvim-treesitter.install").install(ensure_installed)

-- Auto-install parsers when entering a buffer with a new filetype
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("treesitter_auto_install", { clear = true }),
    callback = function()
        local ft = vim.bo.filetype
        if ft == "" then return end
        local lang = vim.treesitter.language.get_lang(ft)
        if not lang then return end
        local ok = pcall(vim.treesitter.language.inspect, lang)
        if ok then return end
        local parsers = require("nvim-treesitter.parsers")
        if parsers[lang] then
            require("nvim-treesitter.install").install({ lang })
        end
    end,
})

-- Textobjects setup
require("nvim-treesitter-textobjects").setup({
    select = { lookahead = true },
    move = { set_jumps = true },
})

local ts_select = function(query, query_group)
    query_group = query_group or "textobjects"
    return function()
        require("nvim-treesitter-textobjects.select").select_textobject(query, query_group)
    end
end

local swap_next = function(query)
    return function() require("nvim-treesitter-textobjects.swap").swap_next(query) end
end

local swap_prev = function(query)
    return function() require("nvim-treesitter-textobjects.swap").swap_previous(query) end
end

local ts_move = require("nvim-treesitter-textobjects.move")
local goto_next_start = function(query, query_group)
    query_group = query_group or "textobjects"
    return function() ts_move.goto_next_start(query, query_group) end
end
local goto_next_end = function(query, query_group)
    query_group = query_group or "textobjects"
    return function() ts_move.goto_next_end(query, query_group) end
end
local goto_prev_start = function(query, query_group)
    query_group = query_group or "textobjects"
    return function() ts_move.goto_previous_start(query, query_group) end
end
local goto_prev_end = function(query, query_group)
    query_group = query_group or "textobjects"
    return function() ts_move.goto_previous_end(query, query_group) end
end

local map = vim.keymap.set

-- Select
map({ "x", "o" }, "a=", ts_select("@assignment.outer"), { desc = "Select outer assignment" })
map({ "x", "o" }, "i=", ts_select("@assignment.inner"), { desc = "Select inner assignment" })
map({ "x", "o" }, "l=", ts_select("@assignment.lhs"), { desc = "Select lhs of assignment" })
map({ "x", "o" }, "r=", ts_select("@assignment.rhs"), { desc = "Select rhs of assignment" })
map({ "x", "o" }, "aa", ts_select("@parameter.outer"), { desc = "Select outer parameter" })
map({ "x", "o" }, "ia", ts_select("@parameter.inner"), { desc = "Select inner parameter" })
map({ "x", "o" }, "ai", ts_select("@conditional.outer"), { desc = "Select outer conditional" })
map({ "x", "o" }, "ii", ts_select("@conditional.inner"), { desc = "Select inner conditional" })
map({ "x", "o" }, "al", ts_select("@loop.outer"), { desc = "Select outer loop" })
map({ "x", "o" }, "il", ts_select("@loop.inner"), { desc = "Select inner loop" })
map({ "x", "o" }, "af", ts_select("@call.outer"), { desc = "Select outer function call" })
map({ "x", "o" }, "if", ts_select("@call.inner"), { desc = "Select inner function call" })
map({ "x", "o" }, "am", ts_select("@function.outer"), { desc = "Select outer method/function" })
map({ "x", "o" }, "im", ts_select("@function.inner"), { desc = "Select inner method/function" })
map({ "x", "o" }, "ac", ts_select("@class.outer"), { desc = "Select outer class" })
map({ "x", "o" }, "ic", ts_select("@class.inner"), { desc = "Select inner class" })

-- Swap
map("n", "g>a", swap_next("@parameter.inner"), { desc = "Swap parameter with next" })
map("n", "g>m", swap_next("@function.outer"), { desc = "Swap function with next" })
map("n", "g<a", swap_prev("@parameter.inner"), { desc = "Swap parameter with prev" })
map("n", "g<m", swap_prev("@function.outer"), { desc = "Swap function with prev" })

-- Move: next starts
map({ "n", "x", "o" }, "]f", goto_next_start("@call.outer"), { desc = "Next function call start" })
map({ "n", "x", "o" }, "]m", goto_next_start("@function.outer"), { desc = "Next method/function start" })
map({ "n", "x", "o" }, "]c", goto_next_start("@class.outer"), { desc = "Next class start" })
map({ "n", "x", "o" }, "]i", goto_next_start("@conditional.outer"), { desc = "Next conditional start" })
map({ "n", "x", "o" }, "]l", goto_next_start("@loop.outer"), { desc = "Next loop start" })
map({ "n", "x", "o" }, "]s", goto_next_start("@local.scope", "locals"), { desc = "Next scope" })
map({ "n", "x", "o" }, "]z", goto_next_start("@fold", "folds"), { desc = "Next fold" })

-- Move: next ends
map({ "n", "x", "o" }, "]F", goto_next_end("@call.outer"), { desc = "Next function call end" })
map({ "n", "x", "o" }, "]M", goto_next_end("@function.outer"), { desc = "Next method/function end" })
map({ "n", "x", "o" }, "]C", goto_next_end("@class.outer"), { desc = "Next class end" })
map({ "n", "x", "o" }, "]I", goto_next_end("@conditional.outer"), { desc = "Next conditional end" })
map({ "n", "x", "o" }, "]L", goto_next_end("@loop.outer"), { desc = "Next loop end" })

-- Move: prev starts
map({ "n", "x", "o" }, "[f", goto_prev_start("@call.outer"), { desc = "Prev function call start" })
map({ "n", "x", "o" }, "[m", goto_prev_start("@function.outer"), { desc = "Prev method/function start" })
map({ "n", "x", "o" }, "[c", goto_prev_start("@class.outer"), { desc = "Prev class start" })
map({ "n", "x", "o" }, "[i", goto_prev_start("@conditional.outer"), { desc = "Prev conditional start" })
map({ "n", "x", "o" }, "[l", goto_prev_start("@loop.outer"), { desc = "Prev loop start" })

-- Move: prev ends
map({ "n", "x", "o" }, "[F", goto_prev_end("@call.outer"), { desc = "Prev function call end" })
map({ "n", "x", "o" }, "[M", goto_prev_end("@function.outer"), { desc = "Prev method/function end" })
map({ "n", "x", "o" }, "[C", goto_prev_end("@class.outer"), { desc = "Prev class end" })
map({ "n", "x", "o" }, "[I", goto_prev_end("@conditional.outer"), { desc = "Prev conditional end" })
map({ "n", "x", "o" }, "[L", goto_prev_end("@loop.outer"), { desc = "Prev loop end" })

-- Autotag
require("nvim-ts-autotag").setup({})

-- Deferred: ts-comments (not needed at startup)
vim.schedule(function()
    vim.pack.add({ "https://github.com/folke/ts-comments.nvim" })
    require("ts-comments").setup({})
end)
