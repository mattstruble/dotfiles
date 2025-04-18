local py = require("utils.python")

return {
    settings = {
        basedpyright = {
            analysis = {
                extraPaths = py.pep582(vim.fn.getcwd()),
                diagnosticSeverityOverrides = {
                    reportUnusedCallResult = false,
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
