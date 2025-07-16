--------------------------
-- LAZY SETUP
--------------------------
require("config.lazy")

-- Load .vimrc
vim.cmd([[
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc
]])
