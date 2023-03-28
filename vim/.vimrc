"Autoreload files when changed externally
set autoread
if has('nvim') "Prevent errors when using standard vim
    autocmd VimEnter * AutoreadLoop
endif
