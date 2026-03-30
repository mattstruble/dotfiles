vim.bo.shiftwidth = 2
vim.bo.expandtab = true
vim.bo.cindent = false
vim.wo[0][0].foldmethod = "indent"
vim.wo[0][0].foldlevel = 99

-- https://github.com/aorith/dotfiles/blob/ffdd40c0a4dcd2a07e1c2ecd8931fa7617744af6/topics/neovim/nvim/after/ftplugin/yaml.lua
vim.api.nvim_create_user_command(
    "YAMLSchemaSelect",
    require("utils.yaml_schema").select,
    {}
)

vim.api.nvim_create_user_command("YAMLSchemaView", function()
    local schema = require("utils.yaml_schema").get_current_schema()
    vim.notify(schema and schema or "No YAML schema", vim.log.levels.INFO)
end, {})

vim.keymap.set(
    "n",
    "<leader>ly",
    "<cmd>YAMLSchemaView<cr>",
    { buffer = 0, desc = "YAML Schema View" }
)
vim.keymap.set(
    "n",
    "<leader>lY",
    "<cmd>YAMLSchemaSelect<cr>",
    { buffer = 0, desc = "YAML Schema Select" }
)
