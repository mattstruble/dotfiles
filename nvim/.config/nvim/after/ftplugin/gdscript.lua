vim.bo.shiftwidth = 4
vim.bo.expandtab = true

-- https://old.reddit.com/r/neovim/comments/13ski66/neovim_configuration_for_godot_4_lsp_as_simple_as/
local port = os.getenv('GDScript_Port') or '6005'
local cmd = vim.lsp.rpc.connect('127.0.0.1', tonumber(port))
local pipe = '/tmp/godot.pipe' -- I use /tmp/godot.pipe

vim.lsp.start({
  name = 'Godot',
  cmd = cmd,
  root_dir = vim.fs.dirname(vim.fs.find({ 'project.godot', '.git' }, { upward = true })[1]),
  on_attach = function(client, bufnr)
    vim.api.nvim_command('echo serverstart("' .. pipe .. '")')
  end
})
