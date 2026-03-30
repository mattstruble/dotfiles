vim.loader.enable()

require("config.globals")
require("config.options")

-- Disable built-in plugins
for _, name in ipairs({
    "gzip",
    "matchit",
    "matchparen",
    "netrwPlugin",
    "tarPlugin",
    "tohtml",
    "tutor",
    "zipPlugin",
}) do
    vim.g["loaded_" .. name] = 1
end

-- Plugin change hooks (must exist before any vim.pack.add)
vim.api.nvim_create_autocmd("PackChanged", {
    callback = function(ev)
        local name, kind = ev.data.spec.name, ev.data.kind

        if name == "nvim-treesitter" and (kind == "install" or kind == "update") then
            if not ev.data.active then
                vim.cmd.packadd("nvim-treesitter")
            end
            vim.cmd("TSUpdate")
        end

        if name == "fff.nvim" and (kind == "install" or kind == "update") then
            if not ev.data.active then
                vim.cmd.packadd("fff.nvim")
            end
            require("fff.download").download_or_build_binary()
        end
    end,
})

-- Non-plugin config (safe before plugins -- callbacks fire later)
require("config.autocmds")
require("config.diagnostics")
require("config.keymaps")

-- Enable built-in extui (replaces noice.nvim)
require("vim._extui").enable({
    enable = true,
    msg = { target = "cmd", timeout = 4000 },
})

-- Legacy vim support
vim.cmd([[
  set runtimepath^=~/.vim runtimepath+=~/.vim/after
  let &packpath = &runtimepath
  source ~/.vimrc
]])
