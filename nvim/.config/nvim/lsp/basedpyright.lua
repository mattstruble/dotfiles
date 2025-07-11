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
        python = {
            pythonPath = py.venv(vim.fn.getcwd()),
            venvPath = py.venv(vim.fn.getcwd()),
        },
    },
    on_new_config = function(new_config, new_root_dir)
        py.env(new_root_dir)
        new_config.settings.python.venvPath = py.venv(new_root_dir)
    end,
}
