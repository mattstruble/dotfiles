--------------------------
-- TREESITTER
--------------------------

local ensure_installed = {
    "bash",
    "c",
    "gitcommit",
    "helm",
    "html",
    "javascript",
    "jsdoc",
    "json",
    "lua",
    "luadoc",
    "luap",
    "markdown",
    "markdown_inline",
    "python",
    "query",
    "regex",
    "tsx",
    "typescript",
    "vim",
    "vimdoc",
    "yaml",
}

return {
    {
        "https://gitlab.com/HiPhish/rainbow-delimiters.nvim.git",
        lazy = true,
    },
    {
        "nvim-treesitter/nvim-treesitter-context",
        lazy = true,
    },
    {
        "nvim-treesitter/nvim-treesitter-textobjects",
        branch = "main",
        lazy = true,
        config = function()
            require("nvim-treesitter-textobjects").setup({
                select = {
                    lookahead = true,
                },
                move = {
                    set_jumps = true,
                },
            })

            local select = function(query, query_group)
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

            local move = require("nvim-treesitter-textobjects.move")
            local goto_next_start = function(query, query_group)
                query_group = query_group or "textobjects"
                return function() move.goto_next_start(query, query_group) end
            end
            local goto_next_end = function(query, query_group)
                query_group = query_group or "textobjects"
                return function() move.goto_next_end(query, query_group) end
            end
            local goto_prev_start = function(query, query_group)
                query_group = query_group or "textobjects"
                return function() move.goto_previous_start(query, query_group) end
            end
            local goto_prev_end = function(query, query_group)
                query_group = query_group or "textobjects"
                return function() move.goto_previous_end(query, query_group) end
            end

            local map = vim.keymap.set

            -- Select keymaps
            map({ "x", "o" }, "a=", select("@assignment.outer"), { desc = "Select outer part of an assignment" })
            map({ "x", "o" }, "i=", select("@assignment.inner"), { desc = "Select inner part of an assignment" })
            map({ "x", "o" }, "l=", select("@assignment.lhs"), { desc = "Select left hand side of an assignment" })
            map({ "x", "o" }, "r=", select("@assignment.rhs"), { desc = "Select right hand side of an assignment" })

            map({ "x", "o" }, "aa", select("@parameter.outer"), { desc = "Select outer part of a parameter/argument" })
            map({ "x", "o" }, "ia", select("@parameter.inner"), { desc = "Select inner part of a parameter/argument" })

            map({ "x", "o" }, "ai", select("@conditional.outer"), { desc = "Select outer part of a conditional" })
            map({ "x", "o" }, "ii", select("@conditional.inner"), { desc = "Select inner part of a conditional" })

            map({ "x", "o" }, "al", select("@loop.outer"), { desc = "Select outer part of a loop" })
            map({ "x", "o" }, "il", select("@loop.inner"), { desc = "Select inner part of a loop" })

            map({ "x", "o" }, "af", select("@call.outer"), { desc = "Select outer part of a function call" })
            map({ "x", "o" }, "if", select("@call.inner"), { desc = "Select inner part of a function call" })

            map({ "x", "o" }, "am", select("@function.outer"), { desc = "Select outer part of a method/function definition" })
            map({ "x", "o" }, "im", select("@function.inner"), { desc = "Select inner part of a method/function definition" })

            map({ "x", "o" }, "ac", select("@class.outer"), { desc = "Select outer part of a class" })
            map({ "x", "o" }, "ic", select("@class.inner"), { desc = "Select inner part of a class" })

            -- Swap keymaps
            map("n", "g>a", swap_next("@parameter.inner"), { desc = "Swap parameter/argument with next" })
            map("n", "g>m", swap_next("@function.outer"), { desc = "Swap function with next" })
            map("n", "g<a", swap_prev("@parameter.inner"), { desc = "Swap parameter/argument with prev" })
            map("n", "g<m", swap_prev("@function.outer"), { desc = "Swap function with previous" })

            -- Move keymaps
            map({ "n", "x", "o" }, "]f", goto_next_start("@call.outer"), { desc = "Next function call start" })
            map({ "n", "x", "o" }, "]m", goto_next_start("@function.outer"), { desc = "Next method/function def start" })
            map({ "n", "x", "o" }, "]c", goto_next_start("@class.outer"), { desc = "Next class start" })
            map({ "n", "x", "o" }, "]i", goto_next_start("@conditional.outer"), { desc = "Next conditional start" })
            map({ "n", "x", "o" }, "]l", goto_next_start("@loop.outer"), { desc = "Next loop start" })
            map({ "n", "x", "o" }, "]s", goto_next_start("@local.scope", "locals"), { desc = "Next scope" })
            map({ "n", "x", "o" }, "]z", goto_next_start("@fold", "folds"), { desc = "Next fold" })

            map({ "n", "x", "o" }, "]F", goto_next_end("@call.outer"), { desc = "Next function call end" })
            map({ "n", "x", "o" }, "]M", goto_next_end("@function.outer"), { desc = "Next method/function def end" })
            map({ "n", "x", "o" }, "]C", goto_next_end("@class.outer"), { desc = "Next class end" })
            map({ "n", "x", "o" }, "]I", goto_next_end("@conditional.outer"), { desc = "Next conditional end" })
            map({ "n", "x", "o" }, "]L", goto_next_end("@loop.outer"), { desc = "Next loop end" })

            map({ "n", "x", "o" }, "[f", goto_prev_start("@call.outer"), { desc = "Prev function call start" })
            map({ "n", "x", "o" }, "[m", goto_prev_start("@function.outer"), { desc = "Prev method/function def start" })
            map({ "n", "x", "o" }, "[c", goto_prev_start("@class.outer"), { desc = "Prev class start" })
            map({ "n", "x", "o" }, "[i", goto_prev_start("@conditional.outer"), { desc = "Prev conditional start" })
            map({ "n", "x", "o" }, "[l", goto_prev_start("@loop.outer"), { desc = "Prev loop start" })

            map({ "n", "x", "o" }, "[F", goto_prev_end("@call.outer"), { desc = "Prev function call end" })
            map({ "n", "x", "o" }, "[M", goto_prev_end("@function.outer"), { desc = "Prev method/function def end" })
            map({ "n", "x", "o" }, "[C", goto_prev_end("@class.outer"), { desc = "Prev class end" })
            map({ "n", "x", "o" }, "[I", goto_prev_end("@conditional.outer"), { desc = "Prev conditional end" })
            map({ "n", "x", "o" }, "[L", goto_prev_end("@loop.outer"), { desc = "Prev loop end" })
        end,
    },
    {
        "nvim-treesitter/nvim-treesitter",
        dependencies = {
            "nvim-treesitter/nvim-treesitter-context",
            "nvim-treesitter/nvim-treesitter-textobjects",
            "https://gitlab.com/HiPhish/rainbow-delimiters.nvim.git",
        },
        build = ":TSUpdate",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
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

                    -- Parser not available, try to install it
                    local parsers = require("nvim-treesitter.parsers")
                    if parsers[lang] then
                        require("nvim-treesitter.install").install({ lang })
                    end
                end,
            })
        end,
    },
    -- Auto-close and auto-rename HTML/JSX/TSX tags
    {
        "windwp/nvim-ts-autotag",
        event = { "BufReadPre", "BufNewFile" },
        opts = {},
    },
}
