" ========== FOLDED TERMINAL: TerminaFold ==========

" Implements terminal sessions where scrollback is composed of
" collapsible/foldable cells containing the commands run and their outputs

let g:tfold_cmdline_regex = '\v^\S*\w+\@\w+.*:.*[$#]\s\zs.*'


command! -nargs=0 TerminafoldStart call terminafold#start()


tnoremap <localleader><leader>s <c-\><c-n>:call terminafold#start()<cr>
tnoremap <localleader><leader>r <c-\><c-n>:call terminafold#scrollback#refresh()<cr>i
" View  Mirror window
"tnoremap <localleader><leader>m <c-\><c-n>:call terminafold#scrollback#refresh()<cr><c-w>l<c-w>\|
" Go back to Term window
"nnoremap <localleader><leader>t <c-w>h<c-w>\|i
" Toggle Term/Mirror View
tnoremap <localleader><leader><localleader> <c-\><c-n>:call terminafold#ui#siwtch_view()<cr>
nnoremap <localleader><leader><localleader> :call terminafold#ui#siwtch_view()<cr>

