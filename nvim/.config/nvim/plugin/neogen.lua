local loaded = false
local function ensure_loaded()
    if loaded then return end
    loaded = true
    local ok, err = pcall(function()
        vim.pack.add({ "https://github.com/danymat/neogen" })
        require("neogen").setup({
            snippet_engine = "mini",
            languages = {
                python = { template = { annotation_convention = "reST" } },
            },
        })
    end)
    if not ok then
        vim.notify("neogen: " .. tostring(err), vim.log.levels.ERROR)
    end
end

vim.keymap.set("n", "<leader>cgf", function()
    ensure_loaded()
    require("neogen").generate()
end, { desc = "Generate function docs" })

vim.keymap.set("n", "<leader>cgc", function()
    ensure_loaded()
    require("neogen").generate({ type = "class" })
end, { desc = "Generate class docs" })
