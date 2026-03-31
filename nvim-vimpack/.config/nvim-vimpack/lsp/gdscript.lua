---@type vim.lsp.Config
return {
    cmd = function(dispatchers)
        local port = tonumber(os.getenv('GDScript_Port')) or 6005
        return vim.lsp.rpc.connect('127.0.0.1', port)(dispatchers)
    end,
    filetypes = { 'gdscript' },
    root_markers = { 'project.godot', '.git' },
    on_attach = function()
        if not vim.tbl_contains(vim.fn.serverlist(), '/tmp/godot.pipe') then
            vim.fn.serverstart('/tmp/godot.pipe')
        end
    end,
}
