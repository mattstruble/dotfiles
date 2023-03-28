--------------------------
-- NVIM TREE 
--------------------------

return { 
    "nvim-tree/nvim-tree.lua",
    config = function()
        vim.g.loaded = 1
        vim.g.loaded_netrwPlugin = 1

        vim.cmd([[ highlight NvimTreeIndentMarker guifg=#3FC5ff ]])


        require("nvim-tree").setup {
            renderer = {
                icons = {
                    glyphs = {
                        folder = {
                            arrow_closed = "", 
                            arrow_open = ""
                        },
                    },
                },
            },
            actions = {
                open_file = {
                    window_picker = {
                        enable = false,
                    },
                },
            },
        }
    end
}
