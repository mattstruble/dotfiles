return {
    "ibhagwan/fzf-lua",
    opts = {
        defaults = {
            hidden = true,
        },
        oldfiles = {
            cwd_only = true,
            stat_file = true, -- verify files exist on disk
            include_current_session = true,
        },
        previewers = {
            builtin = {
                syntax_limit_b = 1024 * 100,
            },
        },
    },
}
