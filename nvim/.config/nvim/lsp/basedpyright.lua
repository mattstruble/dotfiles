local py = require("utils.python")
-- config help taken from https://github.com/astral-sh/ruff-lsp/issues/384
return {
    settings = {
        basedpyright = {
            disableOrganzieImports = true, -- Using Ruff
            disableTaggedHints = true,
            analysis = {
                ignore = { "*" }, -- Using Ruff
                extraPaths = py.pep582(vim.fn.getcwd()),
                diagnosticSeverityOverrides = {
                    reportUnusedCallResult = false,
                    reportUndefinedVariable = "none",
                },
            },
        },
    },
}
