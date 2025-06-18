--------------------
-- REFACTORING
--------------------

return {
    "ThePrimeagen/refactoring.nvim",
    enabled = true,
    lazy = true,
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim",
        "nvim-treesitter/nvim-treesitter",
    },
    config = true,
    -- stylua: ignore
    keys = {
        {"<leader>re", "<Esc><Cmd>lua require('refactoring').refactor('Extract Function')<CR>", mode="v", desc="Refactor Extract Function"},
        {"<leader>rf", "<Esc><Cmd>lua require('refactoring').refactor('Extract Function To File')<CR>]", mode="v", desc="Refactor function to file"},
        {"<leader>rv", "<Esc><Cmd>lua require('refactoring').refactor('Extract Variable')<CR>", mode="v", desc="Refactor extract variable"},
        {"<leader>ri", "<Esc><Cmd>lua require('refactoring').refactor('Inline Variable')<CR>", mode="v", desc="Refactor inline variable"},

        -- Extract block
        {"<leader>rb", "<Cmd>lua require('refactoring').refactor('Extract Block')<CR>", desc="Refactor extract block"},
        {"<leader>rbf", "<Cmd>lua require('refactoring').refactor('Extract Block To File')<CR>", desc="Refactor extract block to file"},

        {"<leader>ri", "<Cmd>lua require('refactoring').refactor('Inline Variable')<CR>", desc="Refactor extract variable under cursor"},

        -- refactoring menu
        {"<leader>rr", "<Esc><cmd>lua require('telescope').extensions.refactoring.refactors()<CR>", desc="Prompt for refactoring operation"}
    }
,
}
