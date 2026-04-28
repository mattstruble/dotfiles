vim.pack.add({
    "https://github.com/luukvbaal/statuscol.nvim",
    "https://github.com/zaakiy/line-justice.nvim",
})

local lj = require("line-justice")
lj.setup({
    line_numbers = {
        theme = nil,
        overrides = {
            CursorLine    = { fg = "#f1e9d2", bold = true },
            AbsoluteAbove = { fg = "#5b5e5a" },
            AbsoluteBelow = { fg = "#5b5e5a" },
            RelativeAbove = { fg = "#70c2be" },
            RelativeBelow = { fg = "#8fb573" },
            WrappedLine   = { fg = "#5b5e5a", italic = true },
        },
    },
})

require("statuscol").setup({
    relculright = true,
    segments = {
        { sign = { namespace = { "diagnostic%.signs" }, maxwidth = 1, colwidth = 1 },           click = "v:lua.ScSa" },
        { sign = { name = { ".*" }, text = { ".*" }, maxwidth = 1, colwidth = 1, wrap = true }, click = "v:lua.ScSa" },
        { text = { lj.segment },                                                                click = "v:lua.ScLa" },
        { sign = { namespace = { "MiniDiffViz" }, maxwidth = 1, colwidth = 1 },                 click = "v:lua.ScSa" },
    },
})
