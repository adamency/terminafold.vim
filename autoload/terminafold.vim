
" Remove /usr/share/nvim/runtime/plugin/netrwPlugin.vim to be able to full screen window at startup
function! terminafold#start()
  if !exists("g:tfold_enable")
    echoerr("You must explicitly enable TerminaFold by setting the variable `g:tfold_enable`")
    return
  endif

  " Check if we are in terminal buffer & that the function has not been run before
  if &buftype ==# 'terminal' && !exists("g:tfold_active")
    let g:tfold_tabterm = tabpagenr()
    let g:tfold_bufterm = bufnr()
    " Create mirror window
    tabnew
    let g:tfold_tabmirror = tabpagenr()
    let g:tfold_bufmirror = bufnr()

    call terminafold#ui#define_folding()
    call terminafold#ui#define_highlights()
    call terminafold#ui#define_signs()
    " Set up browsing between cells with `n` & `N`
    call terminafold#ui#search_cells()

    " Prevent modifications of mirror buffer outside of TerminaFold
    setlocal nomodifiable
    " Go back to term
    exe 'tabn ' . g:tfold_tabterm

    """ Set Automatic Refresh Policy
    let g:tfold_timer_active = 0
    call timer_start(5000, 'terminafold#scrollback#refreshFromTimer', {'repeat': -1})
    "augroup tfold
    "au!
    " Only works in Normal Mode, so not while in Terminal Mode
    "exe '  au CursorHold <buffer=' . g:tfold_bufterm . '> exe "call terminafold#scrollback#refresh()"'
    " Very bad performance as each character typed while in the prompt will trigger a refresh
    "exe '  au TextChangedT <buffer=' . g:tfold_bufterm . '> exe "call terminafold#scrollback#refresh()"'
    "augroup END
    

    " Allow disabling search highlight from a function via an expression mapping (which can be called from the function with feedkeys)
    " which disables search highlighting as a side-effect of the computation of its expression (because the highlighting state is saved and restore between a function call, so a function can't change highlighting normally)
    " See: https://github.com/neovim/neovim/issues/5581
    tnoremap  <expr> <plug>StopSearchHighlight execute('nohlsearch')

    let g:tfold_active = 1
    "autocmd BufWinEnter * if &buftype == 'terminal' | autocmd BufWritePost <buffer> call refresh() | endif
  endif
endfunction

