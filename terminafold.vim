" ========== FOLDED TERMINAL ==========

" Implements terminal sessions where scrollback is composed of
" collapsible/foldable cells containing the commands run and their outputs

" Prepare Search register in order to navigate between prompts
function! TerminaFoldSearchCells()
  norm! mm
  let @/='\v^\S*\w+\@\w+.*:.*[$#]\s\zs.*'
  norm! `m
endfunction

" Define folding method to be used in TerminaFold mode
function! TerminafoldDefineFolding()
  " Fold all terminal command cells (output)
  " https://vi.stackexchange.com/questions/2165/folding-by-regex-search-pattern
  " COAI 8bfecd21-ffc2-4c12-ba13-bc63aaabf6d6
  function! FoldTermCells()
    " Get the current line content as a string
    let line_before = getline(v:lnum - 1)
    let line = getline(v:lnum)

    " Start fold only if current line is the first line after a prompt to
    " preserve syntax highlighting of prompt line (See https://github.com/nvim-treesitter/nvim-treesitter/issues/967 , https://stackoverflow.com/questions/45955033/how-to-keep-vims-folded-line-highlighted-as-the-syntax-of-the-first-line-of-the , https://stackoverflow.com/questions/1813060/syntax-highlighting-in-a-vim-fold-header)
    let prompt_pattern = '^\S*\w\+@\w\+'
    if line =~ prompt_pattern
      return '0'
    endif
    if line_before =~ prompt_pattern
      " Fold
      return '>1'
    else
      " Don't Fold
      return '='
    endif
  endfunction
  " Use above method as folding method
  set foldmethod=expr
  set foldexpr=FoldTermCells()

  " Highlight command lines in prompts
  " https://www.statox.fr/posts/2020/07/vim_flash_yanked_text/
  " Command Line
  hi CommandLine cterm=bold gui=bold ctermfg=12 guifg=#15aabf
  call matchadd('CommandLine', '\v^\S*\w+\@\w+.*[$#]\s\zs.*')
  " user@host
  hi NormalUser ctermfg=170 guifg=#c792ea
  call matchadd('NormalUser', '\v^\S{-}\zs\w+\@\w+\ze\s')
  call matchadd('NormalUser', ' $ ')
  " root@host
  hi RootUser cterm=bold gui=bold ctermfg=204 guifg=#ff5370
  "hi RootUser ctermfg=1 guifg=Red
  call matchadd('RootUser', '\v^\S{-}\zsroot\@\w+\ze\s')
  call matchadd('RootUser', ' # ')
  " CWD
  "hi CWD ctermfg=10 guifg=LightGreen
  hi CWD ctermfg=10 guifg=#2acd50
  call matchadd('CWD', '\v^.*:\zs.*\ze [#$] ')
  " Date
  hi Date ctermfg=180 guifg=#ffcb6b
  call matchadd('Date', '\v(\d\d/){2}\d{4} (\d\d:){2}\d\d')

  " Set up browsing between cells with `n` & `N`
  call TerminaFoldSearchCells()
endfunction

" Remove /usr/share/nvim/runtime/plugin/netrwPlugin.vim to be able to full screen window at startup
function! TerminafoldStart()
  " Check if we are in terminal buffer & that the function has not been run before
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

    call TerminafoldDefineFolding()

    " Force staying at end of scrollback
    normal ggG
    " Go back to term
    wincmd h
    " Works but not satisfactory
    "au CursorHold <buffer> exe "call TerminafoldRefresh()"
    let g:zz_term_active = 1
    "autocmd BufWinEnter * if &buftype == 'terminal' | autocmd BufWritePost <buffer> call refresh() | endif
  endif
endfunction

function! TerminafoldRefresh()
  if &buftype ==# 'terminal'
    " Do not know if works (maybe needed for automatic refresh when in term mode)
    "if mode() == 't'
      "call feedkeys("\<C-\>\<C-N>", 't')
    "endif
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


    call TerminaFoldSearchCells()
    normal ggG
    " Go back to term
    wincmd h
  endif
endfunction

" Resizing a `:term` window currently leads to scrollback text clipping, see https://github.com/neovim/neovim/issues/4997
function TerminaFoldSwitchView()
  if !exists("g:zz_term_active")
    return
  endif
  if &buftype ==# 'terminal'
    call TerminafoldRefresh()
    exe "norm \<c-w>l\<c-w>\|"
  else
    exe "norm \<c-w>h\<c-w>\|0i"
  endif
endfunction

tnoremap <localleader><leader>s <c-\><c-n>:call TerminafoldStart()<cr>
tnoremap <localleader><leader>r <c-\><c-n>:call TerminafoldRefresh()<cr>i
" View  Mirror window
"tnoremap <localleader><leader>m <c-\><c-n>:call TerminafoldRefresh()<cr><c-w>l<c-w>\|
" Go back to Term window
"nnoremap <localleader><leader>t <c-w>h<c-w>\|i
" Toggle Term/Mirror View
tnoremap <localleader><leader><localleader> <c-\><c-n>:call TerminaFoldSwitchView()<cr>
nnoremap <localleader><leader><localleader> :call TerminaFoldSwitchView()<cr>

