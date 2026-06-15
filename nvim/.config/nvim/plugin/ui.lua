local function mode_has(modes)
	return vim.tbl_contains(modes, vim.api.nvim_get_mode().mode)
end

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
                    return mode_has({ "n", "niI", "niR", "niV", "nt", "ntT" }) and "󱣱"
                        or mode_has({ "i", "ic", "ix" }) and ""
                        or mode_has({ "v", "vs", "V", "Vs", "\22", "\22s", "s", "S", "\19" }) and "󰒉"
                        or mode_has({ "c", "cv", "ce", "rm", "r?" }) and ""
                        or mode_has({ "R", "Rc", "Rx", "Rv", "Rvc", "Rvx", "r" }) and ""
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
    extensions = {},
})
