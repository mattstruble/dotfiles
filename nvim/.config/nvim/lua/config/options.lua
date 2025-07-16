local vo = vim.opt
local vg = vim.g
local vw = vim.wo
local vb = vim.bo

-- Global Variables
HomeDir = os.getenv("HOME")
SessionDir = vim.fn.stdpath("data") .. "/sessions"

-- Global Options
vg.mapleader = " "
vg.loaded_perl_provider = 0 -- Do not load Perl

-- Buffer Options
vb.autoindent = true
vb.expandtab = true
vb.shiftwidth = 4
vb.smartindent = true
vb.softtabstop = 4
vb.tabstop = 4
vo.scrolloff = 8

-- Vim options
vo.cmdheight = 0 -- hide command bar
vim.schedule(function() vo.clipboard = "unnamedplus" end) -- use system clipboard
vo.completeopt = { "menuone", "noselect" }
vo.cursorline = true
vo.cursorlineopt = "screenline,number"
vo.emoji = false
vo.fillchars = {
    fold = " ",
    foldopen = "",
    foldclose = "",
    foldsep = " ",
    diff = " ",
    eob = " ",
}

-- VO Folding
vo.foldenable = true
vo.foldlevel = 99
vo.foldlevelstart = 99
vo.foldcolumn = "1"
vo.foldmethod = "expr"
vo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vo.modelines = 1 -- only use folding settings for this file

vo.laststatus = 3 -- global status line

-- White space character display
vo.list = true
vo.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Session options
vo.sessionoptions =
    { "buffers", "curdir", "folds", "resize", "tabpages", "winpos", "winsize" }
--[[
  ShDa (viminfo for vim): session data history
  --------------------------------------------
  ! - Save and restore global variables (their names should be without lowercase letter).
  ' - Specify the maximum number of marked files remembered. It also saves the jump list and the change list.
  < - Maximum of lines saved for each register. All the lines are saved if this is not included, <0 to disable pessistent registers.
  % - Save and restore the buffer list. You can specify the maximum number of buffer stored with a number.
  / or : - Number of search patterns and entries from the command-line history saved. o.history is used if it’s not specified.
  f - Store file (uppercase) marks, use 'f0' to disable.
  s - Specify the maximum size of an item’s content in KiB (kilobyte).
      For the viminfo file, it only applies to register.
      For the shada file, it applies to all items except for the buffer list and header.
  h - Disable the effect of 'hlsearch' when loading the shada file.

  :oldfiles - all files with a mark in the shada file
  :rshada   - read the shada file (:rviminfo for vim)
  :wshada   - write the shada file (:wrviminfo for vim)
]]
vo.shada = [[!,'100,<0,f100,s100,h]]

vo.shell = "/bin/zsh"
vo.shiftround = true -- round indent
vo.ignorecase = true
vo.smartcase = true
vo.hlsearch = false
vo.incsearch = true
vo.splitright = true
vo.splitbelow = true
vo.textwidth = 120
vo.timeoutlen = 300
vo.updatetime = 250
vo.wildmode = "list:longest"
vo.wildignore = { "*/.git/*", "*/.venv/*" }
vo.termguicolors = true
vo.background = "dark"
vo.signcolumn = "yes"
vo.isfname:append("@-@")
vo.backspace = "indent,eol,start"
vo.iskeyword:append("-")

-- Create folders for backups, undos, swaps, sessions, etc
vim.schedule(function()
    vim.cmd("silent call mkdir(stdpath('data').'/backups', 'p', '0700')")
    vim.cmd("silent call mkdir(stdpath('data').'/undos', 'p', '0700')")
    vim.cmd("silent call mkdir(stdpath('data').'/swaps', 'p', '0700')")
    vim.cmd("silent call mkdir(stdpath('data').'/sessions', 'p', '0700')")

    vo.backupdir = vim.fn.stdpath("data") .. "/backups" -- Use backup files
    vo.directory = vim.fn.stdpath("data") .. "/swaps" -- Use Swap files
    vo.undodir = vim.fn.stdpath("data") .. "/undos" -- Set the undo directory
end)

vo.undofile = true
vo.undolevels = 1000
vo.pumheight = 5

-- Window options
vw.colorcolumn = "80,120"
vw.numberwidth = 2 -- make line number column thinner
vw.list = true -- show invisible characters
vw.wrap = false
vw.number = true
vw.relativenumber = true
vw.signcolumn = "yes"
