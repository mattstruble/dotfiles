vim.pack.add({
    "https://github.com/luukvbaal/statuscol.nvim",
    "https://github.com/zaakiy/line-justice.nvim",
})

local lj = require("line-justice")
lj.setup({ line_numbers = { theme = nil } })

local builtin = require("statuscol.builtin")
require("statuscol").setup({
    relculright = true,
    segments = {
        { text = { builtin.foldfunc },                                                      click = "v:lua.ScFa" },
        { sign = { namespace = { "MiniDiffViz" }, maxwidth = 1, colwidth = 1, auto = true }, click = "v:lua.ScSa" },
        { sign = { namespace = { "diagnostic/signs" }, maxwidth = 2, auto = true },         click = "v:lua.ScSa" },
        { sign = { name = { ".*" }, maxwidth = 2, colwidth = 1, auto = true, wrap = true }, click = "v:lua.ScSa" },
        { text = { lj.segment },                                                            click = "v:lua.ScLa" },
    },
})
