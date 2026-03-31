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
            local ok, err = pcall(require("fff.download").download_or_build_binary)
            if not ok then
                vim.notify("fff.nvim build failed: " .. tostring(err), vim.log.levels.ERROR)
            end
        end
    end,
})

-- Non-plugin config (safe before plugins -- callbacks fire later)
require("config.autocmds")
require("config.diagnostics")
require("config.keymaps")

-- Built-in extui: nightly-only, not in stable 0.12.
-- noice.nvim handles cmdline/message UI for now (see plugin/noice.lua).
-- When extui lands in stable, noice can be dropped and this uncommented:
-- pcall(function()
--     require("vim._extui").enable({
--         enable = true,
--         msg = { target = "cmd", timeout = 4000 },
--     })
-- end)

-- Legacy vim support
vim.cmd([[
  set runtimepath^=~/.vim runtimepath+=~/.vim/after
  let &packpath = &runtimepath
  source ~/.vimrc
]])
