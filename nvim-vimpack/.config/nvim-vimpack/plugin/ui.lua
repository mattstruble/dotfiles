local mode = require("utils.mode")

local get_py_venv = function()
    local venv_path = os.getenv("VIRTUAL_ENV")
    if venv_path then
        local venv_name = vim.fn.fnamemodify(venv_path, ":t")
        return (".venv: %s  "):format(venv_name)
    end
    local conda_env = os.getenv("CONDA_DEFAULT_ENV")
    if conda_env then
        return ("conda: %s  "):format(conda_env)
    end
    return ""
end

vim.pack.add({
    "https://github.com/nvim-lualine/lualine.nvim",
    "https://github.com/meuter/lualine-so-fancy.nvim",
})

require("lualine").setup({
    options = {
        icons_enabled = true,
        component_separators = "|",
        section_separators = { left = "", right = "" },
    },
    sections = {
        lualine_a = {
            {
                "mode",
                fmt = function()
                    return mode.isNormal() and "󱣱"
                        or mode.isInsert() and ""
                        or mode.isVisual() and "󰒉"
                        or mode.isCommand() and ""
                        or mode.isReplace() and ""
                        or vim.api.nvim_get_mode().mode == "t" and ""
                        or ""
                end,
                separator = { left = " " },
                right_padding = 2,
            },
        },
        lualine_b = {
            { "fancy_branch" },
            { "fancy_diff" },
        },
        lualine_c = {
            { get_py_venv },
        },
        lualine_x = { "lsp_status" },
        lualine_y = {
            { "fancy_diagnostics" },
            { "fancy_searchcount" },
            { "fancy_location" },
        },
        lualine_z = {
            {
                "fancy_filetype",
                separator = { right = " " },
                left_padding = 2,
            },
        },
    },
    extensions = { "nvim-tree" },
})
