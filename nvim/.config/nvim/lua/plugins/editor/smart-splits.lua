-- smart-splits.nvim: seamless navigation between neovim and kitty splits
-- Replaces native <C-w>h/j/k/l with multiplexer-aware navigation
return {
    "mrjones2014/smart-splits.nvim",
    lazy = false,
    opts = {
        -- The default behavior when at the edge of a neovim split:
        -- "wrap" wraps to the other side, "split" creates a new split,
        -- "stop" does nothing. We want kitty to handle it, so we use the
        -- multiplexer integration which overrides this behavior.
        at_edge = "stop",
    },
    keys = {
        -- Navigation (Ctrl+hjkl)
        { "<C-h>", function() require("smart-splits").move_cursor_left() end,  desc = "Move to left split" },
        { "<C-j>", function() require("smart-splits").move_cursor_down() end,  desc = "Move to below split" },
        { "<C-k>", function() require("smart-splits").move_cursor_up() end,    desc = "Move to above split" },
        { "<C-l>", function() require("smart-splits").move_cursor_right() end, desc = "Move to right split" },

        -- Resizing (Ctrl+Alt+hjkl) -- matches kitty's Ctrl+A>Ctrl+hjkl resize
        { "<C-A-h>", function() require("smart-splits").resize_left() end,  desc = "Resize split left" },
        { "<C-A-j>", function() require("smart-splits").resize_down() end,  desc = "Resize split down" },
        { "<C-A-k>", function() require("smart-splits").resize_up() end,    desc = "Resize split up" },
        { "<C-A-l>", function() require("smart-splits").resize_right() end, desc = "Resize split right" },

        -- Swap buffers (Ctrl+A + hjkl with leader -- optional, nice to have)
        { "<leader><leader>h", function() require("smart-splits").swap_buf_left() end,  desc = "Swap buffer left" },
        { "<leader><leader>j", function() require("smart-splits").swap_buf_down() end,  desc = "Swap buffer down" },
        { "<leader><leader>k", function() require("smart-splits").swap_buf_up() end,    desc = "Swap buffer up" },
        { "<leader><leader>l", function() require("smart-splits").swap_buf_right() end, desc = "Swap buffer right" },
    },
}
