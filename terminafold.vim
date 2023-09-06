" ========== FOLDED TERMINAL ==========

" Implements terminal sessions where scrollback is composed of
" collapsible/foldable cells containing the commands run and their outputs


function! TerminatorStart()
  " Check if we are in terminal mode & that the function has not been run before
  if &buftype ==# 'terminal' && !exists("g:zz_term_active")
    " Create mirror window
    vnew
    " Copy term buffer content
    b#
    %y
    " Paste term buffer into mirror buffer
    b#
    " (IMPORTANT: and Remove Last Line of scrollback to ensure correct future scrollback
    " because the last prompt line will be modified in the future as a command will by typed to the prompt)
    " COAI 337f24f0-da34-455a-a3b7-70054e3271c8 + https://stackoverflow.com/questions/42247108/how-to-nest-commands-in-c-option-of-vim
    "execute "normal! i\<C-r>0\<Esc>"
    "norm dddd
    norm pggddGdd
    " Save current terminal EOF for next refresh
    let g:zz_term_mirror_end = line('$')

    " Fold all terminal command cells (prompt + output)
    " https://vi.stackexchange.com/questions/2165/folding-by-regex-search-pattern
    " COAI 8bfecd21-ffc2-4c12-ba13-bc63aaabf6d6
    function! FoldTermCells(lnum)
      " Get the current line content as a string
      let line = getline(a:lnum)

      " Check if the line starts with "[e]"
      if line =~ '^\[e\]'
        " Fold
        return '>1'
      else
        " Don't Fold
        return '='
      endif
    endfunction
    " Use above method as folding method
    set foldmethod=expr
    set foldexpr=FoldTermCells(v:lnum)

    " Force staying at end of scrollback
    normal ggG
    " Go back to term
    wincmd h
    normal i
    let g:zz_term_active = 1
  endif
endfunction

function! TerminatorRefresh()
  if &buftype ==# 'terminal'
    wincmd l
    b#
    " Retrieve new scrollback only from end of last refresh for better performance on big scrollbacks
    let last_mirrored_line = g:zz_term_mirror_end
    let last_term_line = line('$') - 1
    " IMPORTANT: At start the `:terminal` buffer is filled with empty lines until the end
    " of the screen, so the scrollback history will not match between runs until a full
    " screen of scrollback has been filled and copied to the mirror (current screen size: 53 lines)
    if last_mirrored_line < 100
      " Replace mirror by full term content (small scrollback here so not a problem)
      %y
      b#
      " Delete old content into black hole register to keep previously copied term content
      norm gg"_dGpggddGdd
    else
      " If term content has been added
      if last_mirrored_line < last_term_line
          " Copy & Append Remaining Scrollback to mirror buffer
          let range = last_mirrored_line + 1 . ',' . last_term_line
          silent execute range . 'yank'
          b#
          let start_put_line = last_mirrored_line
          execute start_put_line . 'put'
      else
          b#
      endif
    endif
    let g:zz_term_mirror_end = line('$')


    normal ggG
    " Go back to term
    wincmd h
    normal i
  endif
endfunction

tnoremap <localleader><leader>s <c-\><c-n>:call TerminatorStart()<cr>
tnoremap <localleader><leader>r <c-\><c-n>:call TerminatorRefresh()<cr>
tnoremap <localleader><leader>w <c-\><c-n><c-w>l

