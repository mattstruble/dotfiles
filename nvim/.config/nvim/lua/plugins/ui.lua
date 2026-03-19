local mode = require("utils.mode")

--- Get the name of the current venv in Python
--- @return string|nil name of venv or nil
--- From JDHao; see https://www.reddit.com/r/neovim/comments/16ya0fr/show_the_current_python_virtual_env_on_statusline/
local get_py_venv = function()
    local venv_path = os.getenv("VIRTUAL_ENV")
    if venv_path then
        local venv_name = vim.fn.fnamemodify(venv_path, ":t")
        return (".venv: %s  "):format(venv_name)
    end

    local conda_env = os.getenv("CONDA_DEFAULT_ENV")
    if conda_env then return ("conda: %s  "):format(conda_env) end

    return ""
end

return {
    {
        "nvim-lualine/lualine.nvim",
        lazy = true,
        enabled = true,
        event = { "BufReadPre" },
        dependencies = {
            "meuter/lualine-so-fancy.nvim",
            "folke/noice.nvim",
        },
        after = "noice.nvim",
        opts = {
            options = {
                icons_enabled = true,
                component_separators = "|",
                section_separators = { left = "", right = "" },
            },
            sections = {
                lualine_a = {
                    {
                        "mode",
                        fmt = function()
                            return mode.isNormal() and "󱣱"
                                or mode.isInsert() and ""
                                or mode.isVisual() and "󰒉"
                                or mode.isCommand() and ""
                                or mode.isReplace() and ""
                                or vim.api.nvim_get_mode().mode == "t" and ""
                                or ""
                        end,
                        separator = { left = " " },
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
                        separator = { right = " " },
                        left_padding = 2,
                    },
                },
            },
            extensions = {
                "nvim-tree",
            },
        },
    },
    {
        "MunifTanjim/nui.nvim",
        lazy = true,
        event = "VeryLazy",
    },

    {
        "folke/noice.nvim",
        lazy = true,
        event = "VeryLazy",
        dependencies = {
            "MunifTanjim/nui.nvim",
        },
        config = function()
            require("noice").setup({
                lsp = {
                    -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
                    override = {
                        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
                        ["vim.lsp.util.stylize_markdown"] = true,
                        ["cmp.entry.get_documentation"] = true,
                    },
                    signature = { enabled = true },
                    hover = { enabled = true },
                },
                presets = {
                    inc_rename = true,
                    bottom_search = true,
                    command_palette = true,
                    long_message_to_split = true,
                    lsp_doc_border = true,
                },
                notify = { enabled = false },
            })
        end,
    },
}
