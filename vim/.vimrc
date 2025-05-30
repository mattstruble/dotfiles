"Autoreload files when changed externally
" https://stackoverflow.com/questions/2157914/can-vim-monitor-realtime-changes-to-a-file
set autoread | au CursorHold * checktime

set splitbelow splitright

" Correct spelling mistakes on the fly
" https://old.reddit.com/r/neovim/comments/1k4efz8/share_your_proudest_config_oneliners/mo9ethh/
set spelllang=en
au BufRead *.txt setlocal spell
au BufRead *.md setlocal spell

inoremap <C-l> <c-g>u<Esc>[s1z=`]a<c-g>u

" Allow loading current directory .vimrc or .nvim.lua
set exrc
set secure " Disallow shell, autocmd, and write commands
