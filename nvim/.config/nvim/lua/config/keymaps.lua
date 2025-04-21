vim.g.mapleader = " "

local keymap = vim.keymap

-- general keymaps

keymap.set("i", "jk", "<ESC>")

keymap.set("n", "<leader>nh", ":nohl<CR>")

keymap.set("n", "x", '"_x')

keymap.set("n", "<leader>+", "<C-a>")
keymap.set("n", "<leader>-", "<C-x>")

-- keymap.set("n", "<leader>sv", "<C-w>v") -- split vertically
-- keymap.set("n", "<leader>sh", "<C-w>s") -- split horizontally
-- keymap.set("n", "<leader>se", "<C-w>=") -- make split equal width
-- keymap.set("n", "<leader>sx", ":close<CR>") -- close current split

keymap.set("n", "<leader>to", ":tabnew<CR>") -- open new tab
keymap.set("n", "<leader>tx", ":tabclose<CR>") -- close curr tab
keymap.set("n", "<leader>tn", ":tabn<CR>") -- go to next tab
keymap.set("n", "<leader>tp", ":tabp<CR>") -- go to previous tab

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
keymap.set("n", "<leader>f", require("conform").format)

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
keymap.set("n", "n", "nzz")
keymap.set("n", "N", "Nzz")
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

keymap.set("x", "<leader>p", [["_dP]])

keymap.set("n", "Q", "<nop>")

-- Copy to clipboard
keymap.set({ "n", "v" }, "<leader>y", [["+y]])
keymap.set("n", "<leader>Y", [["+Y]])

-- Delete without overwriting buffer
keymap.set({ "n", "v" }, "<leader>d", [["_d]])

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
