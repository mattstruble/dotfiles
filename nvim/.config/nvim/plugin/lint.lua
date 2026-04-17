vim.pack.add({ "https://github.com/mfussenegger/nvim-lint" })

local lint = require("lint")

lint.linters_by_ft = {
    ansible = { "ansible_lint" },
    fennel = { "fennel" },
    gdscript = { "gdscript_formatter" },
    git = { "gitlint" },
    markdown = { "markdownlint", "write_good" },
    nix = { "nix" },
    rust = { "cargo" },
    sh = { "shellcheck" },
    bash = { "shellcheck" },
    sql = { "sqruff" },
    tex = { "lacheck" },
    text = { "write_good" },
    yaml = { "yamllint", "actionlint" },
    ["*"] = { "codespell" },
}

-- Custom linter configs
lint.linters.gdscript_formatter = {
    cmd = "gdscript-formatter",
    stdin = false,
    args = { "lint", function() return vim.api.nvim_buf_get_name(0) end },
    stream = "stdout",
    ignore_exitcode = true,
    parser = function(output, bufnr)
        local diagnostics = {}
        local severity_map = {
            error = vim.diagnostic.severity.ERROR,
            warning = vim.diagnostic.severity.WARN,
            info = vim.diagnostic.severity.INFO,
        }
        for line in output:gmatch("[^\n]+") do
            local _, lnum, rule, sev, msg = line:match("^([^:]+):(%d+):([^:]+):(%w+): (.+)$")
            if lnum then
                table.insert(diagnostics, {
                    lnum = tonumber(lnum) - 1,
                    col = 0,
                    severity = severity_map[sev] or vim.diagnostic.severity.WARN,
                    message = msg,
                    source = "gdscript-formatter",
                    code = rule,
                })
            end
        end
        return diagnostics
    end,
}

lint.linters.cargo = {
    cmd = "cargo",
    stdin = false,
    args = { "check" },
    stream = "both",
    ignore_exitcode = false,
    env = nil,
}

local function debounce(ms, fn)
    local timer = vim.uv.new_timer()
    return function(...)
        local argv = { ... }
        timer:start(ms, 0, function()
            timer:stop()
            vim.schedule_wrap(fn)(unpack(argv))
        end)
    end
end

local function do_lint()
    local names = lint._resolve_linter_by_ft(vim.bo.filetype)
    names = vim.list_extend({}, names)

    if #names == 0 then
        vim.list_extend(names, lint.linters_by_ft["_"] or {})
    end
    vim.list_extend(names, lint.linters_by_ft["*"] or {})

    local ctx = { filename = vim.api.nvim_buf_get_name(0) }
    ctx.dirname = vim.fn.fnamemodify(ctx.filename, ":h")
    names = vim.tbl_filter(function(name)
        local linter = lint.linters[name]
        if not linter then
            vim.notify("Linter not found: " .. name, vim.log.levels.WARN, { title = "nvim-lint" })
        end
        return linter and not (type(linter) == "table" and linter.condition and not linter.condition(ctx))
    end, names)

    if #names > 0 then
        lint.try_lint(names)
    end
end

vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
    group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
    callback = debounce(100, do_lint),
})
