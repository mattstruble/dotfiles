vim.g.mapleader = " "

local keymap = vim.keymap

-- Smart j/k: move by visual line when no count, by real line when count given
keymap.set({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { desc = "Down", expr = true, silent = true })
keymap.set({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { desc = "Up", expr = true, silent = true })

-- general keymaps

keymap.set("i", "jk", "<ESC>")

keymap.set("n", "<leader>uh", ":nohl<CR>", { desc = "Clear Search Highlighting" })

keymap.set("n", "x", '"_x')

keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment" })
keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement" })

-- keymap.set("n", "<leader>sv", "<C-w>v") -- split vertically
-- keymap.set("n", "<leader>sh", "<C-w>s") -- split horizontally
-- keymap.set("n", "<leader>se", "<C-w>=") -- make split equal width
-- keymap.set("n", "<leader>sx", ":close<CR>") -- close current split

-- Tab management
keymap.set("n", "<leader><tab><tab>", "<cmd>tabnew<cr>", { desc = "New Tab" })
keymap.set("n", "<leader><tab>d", "<cmd>tabclose<cr>", { desc = "Close Tab" })
keymap.set("n", "<leader><tab>]", "<cmd>tabnext<cr>", { desc = "Next Tab" })
keymap.set("n", "<leader><tab>[", "<cmd>tabprevious<cr>", { desc = "Previous Tab" })
keymap.set("n", "<leader><tab>l", "<cmd>tablast<cr>", { desc = "Last Tab" })
keymap.set("n", "<leader><tab>o", "<cmd>tabonly<cr>", { desc = "Close Other Tabs" })
keymap.set("n", "<leader><tab>f", "<cmd>tabfirst<cr>", { desc = "First Tab" })

-- much easier to me to undo and re-do all within the same letter
vim.keymap.set("n", "U", "<C-r>")

-- Tab and S-Tab to cycle through buffers
-- vim.keymap.set("n", "<S-Tab>", "<cmd>:bprevious<cr>")
-- vim.keymap.set("n", "<Tab>", "<cmd>:bnext<cr>")

-- ctrl-backspace to delete entire word
vim.keymap.set("i", "<C-BS>", "<Esc>cvb", {})

-- quick change inside word
vim.keymap.set("n", "<cr>", "ciw")

-- so the cursor does not jump back to where you started the selection
vim.keymap.set("v", "y", "ygv<esc>")

---
-- The Primeagen
---
-- Format is handled by <leader>cf in plugins/coding/conform.lua

-- Allow highlighting and moving blocks of code in visual mode
keymap.set("v", "J", ":m '>+1<CR>gv=gv")
keymap.set("v", "K", ":m '<-2<CR>gv=gv")

keymap.set("n", "J", "mzJ`z") -- Move line below to end of current line with space in between

-- Keep cursor centered when navigating
keymap.set("n", "<C-d>", "<C-d>zz")
keymap.set("n", "<C-u>", "<C-u>zz")
keymap.set("n", "n", "nzzzv")
keymap.set("n", "N", "Nzzzv")
keymap.set("n", "{", "{zz")
keymap.set("n", "}", "}zz")
keymap.set("n", "G", "Gzz")
keymap.set("n", "i", "zzi")
keymap.set("n", "I", "zzI")
keymap.set("n", "o", "zzo")
keymap.set("n", "O", "zzO")
keymap.set("n", "a", "zza")
keymap.set("n", "A", "zzA")
keymap.set("n", "s", "zzs")
keymap.set("n", "S", "zzS")
keymap.set("n", "c", "zzc")
keymap.set("n", "C", "zzC")

keymap.set("x", "<leader>p", [["_dP]], { desc = "Paste Without Overwrite" })

keymap.set("n", "Q", "<nop>")

-- Copy to clipboard
keymap.set({ "n", "v" }, "<leader>y", [["+y]], { desc = "Yank to Clipboard" })
keymap.set("n", "<leader>Y", [["+Y]], { desc = "Yank Line to Clipboard" })

-- Delete without overwriting buffer
keymap.set({ "n", "v" }, "<leader>d", [["_d]], { desc = "Delete to Void Register" })

-- Only search within the visual area when in visual mode
vim.keymap.set("x", "/", "<Esc>/\\%V") -- search wiithin visual selection

-- Duplicate line and comment first line, adds [count] to front.
-- https://old.reddit.com/r/neovim/comments/1k4efz8/share_your_proudest_config_oneliners/mob2hwx/
vim.keymap.set(
    "n",
    "ycc",
    '"yy" . v:count1 . "gcc\']p"',
    { remap = true, expr = true }
)

-- Navigate between quickfix items
-- https://github.com/exosyphon/nvim/blob/main/lua/exosyphon/remaps.lua
vim.keymap.set(
    "n",
    "<leader>h",
    "<cmd>cnext<CR>zz",
    { desc = "Forward qfixlist" }
)
vim.keymap.set(
    "n",
    "<leader>;",
    "<cmd>cprev<CR>zz",
    { desc = "Backward qfixlist" }
)

-- Split navigation is handled by smart-splits.nvim (see plugins/editor/smart-splits.lua)
-- Provides seamless Ctrl+h/j/k/l navigation between neovim and kitty splits

-- ┌───────────────────────────────────────────┐
-- │ Essential keymaps (from LazyVim defaults) │
-- └───────────────────────────────────────────┘

-- Lazy plugin manager
keymap.set("n", "<leader>l", "<cmd>Lazy<cr>", { desc = "Lazy" })

-- Quit
keymap.set("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit All" })

-- New file
keymap.set("n", "<leader>fn", "<cmd>enew<cr>", { desc = "New File" })

-- Diagnostics
keymap.set("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line Diagnostics" })

local function diagnostic_goto(next, severity)
    local count = next and 1 or -1
    severity = severity and vim.diagnostic.severity[severity] or nil
    return function() vim.diagnostic.jump({ count = count, severity = severity }) end
end

keymap.set("n", "]d", diagnostic_goto(true), { desc = "Next Diagnostic" })
keymap.set("n", "[d", diagnostic_goto(false), { desc = "Prev Diagnostic" })
keymap.set("n", "]e", diagnostic_goto(true, "ERROR"), { desc = "Next Error" })
keymap.set("n", "[e", diagnostic_goto(false, "ERROR"), { desc = "Prev Error" })
keymap.set("n", "]w", diagnostic_goto(true, "WARN"), { desc = "Next Warning" })
keymap.set("n", "[w", diagnostic_goto(false, "WARN"), { desc = "Prev Warning" })

-- Save file
keymap.set({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save File" })

-- Better indenting (stay in visual mode)
keymap.set("x", "<", "<gv")
keymap.set("x", ">", ">gv")

-- Add comment below/above: provided by Comment.nvim once loaded (gco/gcO)

-- Keywordprg
keymap.set("n", "<leader>K", "<cmd>norm! K<cr>", { desc = "Keywordprg" })

-- Add undo break-points
keymap.set("i", ",", ",<c-g>u")
keymap.set("i", ".", ".<c-g>u")
keymap.set("i", ";", ";<c-g>u")

-- Switch to other buffer
keymap.set("n", "<leader>bb", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })

-- Windows
-- NOTE: <leader>- is not added here because it's already mapped to <C-x> (decrement)
