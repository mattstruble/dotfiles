require("config.globals")
require("config.options")

-- Begin Lazy install and plugin setup
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "--branch=stable",
        lazyrepo,
        lazypath,
    })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out, "WarningMsg" },
            { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    spec = {
        { import = "plugins" },
    },
    install = {
        colorscheme = { "bamboo" },
    },
    checker = {
        enabled = true,
        notify = false,
        frequency = 900,
    },
    change_detection = {
        enabled = true,
        notify = false,
    },
    ui = {
        border = "rounded",
        icons = {
            plugin = "",
        },
    },
    performance = {
        cache = {
            enabled = true,
        },
        rtp = {
            disabled_plugins = {
                "gzip",
                "matchit",
                "matchparen",
                "netrwPlugin",
                "tarPlugin",
                "tohtml",
                "tutor",
                "zipPlugin",
            },
        },
    },
})

require("config.autocmds")
require("config.diagnostics")

vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    callback = function() require("config.keymaps") end,
})
