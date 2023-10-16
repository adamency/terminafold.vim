" ========== FOLDED TERMINAL: TerminaFold ==========

" Implements terminal sessions where scrollback is composed of
" collapsible/foldable cells containing the commands run and their outputs

" Prepare Search register in order to navigate between prompts
function! TerminaFoldSearchCells()
  norm! mm
  let s:cmdline_regex = '\v^\S*\w+\@\w+.*:.*[$#]\s\zs.*'
  let @/ = s:cmdline_regex
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
endfunction

function! TerminafoldDefineHighlights()
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
endfunction

function! TerminafoldDefineSigns()
  " Define Highlights for Greeter
  hi TfGreeter cterm=bold gui=bold guifg=#FF8C00 guibg=#1e1e1e
  hi TfGreeterTerm cterm=bold gui=bold guifg=#003366 guibg=#1e1e1e
  hi TfGreeterMirror cterm=bold gui=bold guifg=#990000 guibg=#1e1e1e

  " Define Signs
  call sign_define('tfoldg', { "text" : 'TF',  "texthl" : 'TfGreeter'})
  call sign_define('tfoldt', { "text" : ' T',  "texthl" : 'TfGreeterTerm'})
  call sign_define('tfoldm', { "text" : ' M',  "texthl" : 'TfGreeterMirror'})

  " Place Signs
  " Term Signs
  call sign_place(1, 'tfold', 'tfoldg', s:bufterm, {'lnum' : 1})
  call sign_place(2, 'tfold', 'tfoldt', s:bufterm, {'lnum' : 1})
  " Mirror Signs
  let g:tfold_signs_inited = 1
  call TerminafoldRedefineMirrorSigns()
endfunction

function! TerminafoldRedefineMirrorSigns()
  " Nvim deletes signs on lines that are deleted so
  " until we exceed the limit mentioned in NOTE1 we need to replace the signs in the mirror
  if !exists("g:tfold_signs_inited")
    return
  endif
  call sign_place(3, 'tfold', 'tfoldg', s:bufmirror, {'lnum' : 1})
  call sign_place(4, 'tfold', 'tfoldm', s:bufmirror, {'lnum' : 1})
endfunction

" Remove /usr/share/nvim/runtime/plugin/netrwPlugin.vim to be able to full screen window at startup
function! TerminafoldStart()
  if !exists("g:tfold_enable")
    echoerr("You must explicitly enable TerminaFold by setting the variable `g:tfold_enable`")
    return
  endif

  " Check if we are in terminal buffer & that the function has not been run before
  if &buftype ==# 'terminal' && !exists("g:tfold_active")
    let s:tabterm = tabpagenr()
    let s:bufterm = bufnr()
    " Create mirror window
    tabnew
    let s:tabmirror = tabpagenr()
    let s:bufmirror = bufnr()
    " Copy term buffer content
    exe 'b' . s:bufterm
    %y
    " Paste term buffer into mirror buffer
    exe 'b' . s:bufmirror
    " (IMPORTANT: and Remove Last Line of scrollback to ensure correct future scrollback
    " because the last prompt line will be modified in the future as a command will by typed to the prompt)
    " COAI 337f24f0-da34-455a-a3b7-70054e3271c8 + https://stackoverflow.com/questions/42247108/how-to-nest-commands-in-c-option-of-vim
    "execute "normal! i\<C-r>0\<Esc>"
    norm pggddGdd
    " Save current terminal EOF for next refresh
    let g:tfold_mirror_end = line('$')

    call TerminafoldDefineFolding()
    call TerminafoldDefineHighlights()
    call TerminafoldDefineSigns()
    " Set up browsing between cells with `n` & `N`
    call TerminaFoldSearchCells()

    " Force staying at end of scrollback
    normal G
    " Prevent modifications of mirror buffer outside of TerminaFold
    setlocal nomodifiable
    " Go back to term
    exe 'tabn ' . s:tabterm

    """ Set Automatic Refresh Policy
    call timer_start(5000, 'TerminafoldRefreshFromTimer', {'repeat': -1})
    "augroup tfold
    "au!
    " Only works in Normal Mode, so not while in Terminal Mode
    "exe '  au CursorHold <buffer=' . s:bufterm . '> exe "call TerminafoldRefresh()"'
    " Very bad performance as each character typed while in the prompt will trigger a refresh
    "exe '  au TextChangedT <buffer=' . s:bufterm . '> exe "call TerminafoldRefresh()"'
    "augroup END
    

    " Allow disabling search highlight from a function via an expression mapping (which can be called from the function with feedkeys)
    " which disables search highlighting as a side-effect of the computation of its expression (because the highlighting state is saved and restore between a function call, so a function can't change highlighting normally)
    " See: https://github.com/neovim/neovim/issues/5581
    tnoremap  <expr> <plug>StopSearchHighlight execute('nohlsearch')

    let g:tfold_active = 1
    "autocmd BufWinEnter * if &buftype == 'terminal' | autocmd BufWritePost <buffer> call refresh() | endif
  endif
endfunction

function! TerminafoldRefresh()
  if !exists("g:tfold_active")
    return
  endif

  let bufcurrent = bufnr()

  " Get Last mirrored line
  exe 'b' . s:bufmirror
  let last_mirrored_line = g:tfold_mirror_end
  let last_mirrored_line_content = getline(last_mirrored_line)

  " Retrieve new scrollback only from end of last refresh for better performance on big scrollbacks
  exe 'b' . s:bufterm
  let last_term_line = line('$') - 1
  let new_line_count = last_term_line - last_mirrored_line 
  " NOTE1: At start the `:terminal` buffer is filled with empty lines until the end
  " of the screen, so the scrollback history will not match between command runs until a full
  " screen of scrollback has been filled and copied to the mirror (current screen size: 53 lines)
  " As we thus can't know the difference before this threshold, we replace the entire buffer until attained
  " Also check if we are not in a TUI by checking if there is the 1st line is a prompt line (or the 2nd one to account for echo line indicator when loading shell profile)
  if last_mirrored_line < 100 && (getline(1) =~ s:cmdline_regex || getline(2) =~ s:cmdline_regex)
    " Replace mirror by full term content (small scrollback here so not a problem)
    %y
    exe 'b' . s:bufmirror
    setlocal modifiable
    " Delete old content into black hole register to keep previously copied term content
    norm gg"_dGpggddGdd
    call TerminafoldRedefineMirrorSigns()
    setlocal nomodifiable
    echo "Refreshed TerminaFold Mirror (" . last_term_line . " lines)"
  " If term content has been added (also check that scrollback are equal to prevent mirroring when a TUI program is opened)
  elseif new_line_count > 0 && getline(last_mirrored_line) == last_mirrored_line_content
    " Copy & Append Remaining Scrollback to mirror buffer
    let range = last_mirrored_line + 1 . ',' . last_term_line
    silent execute range . 'yank'
    exe 'b' . s:bufmirror
    setlocal modifiable
    let start_put_line = last_mirrored_line
    silent execute start_put_line . 'put'
    setlocal nomodifiable
    echo "Refreshed TerminaFold Mirror (" . new_line_count . " more lines)"
  else
    exe 'b' . s:bufmirror
  endif

  " Post-processing in bufmirror
  let g:tfold_mirror_end = line('$')
  call TerminaFoldSearchCells()

  " Go back to current buffer
  exe 'b' . bufcurrent
endfunction

function! TerminafoldRefreshFromTimer(timer)
  call TerminafoldRefresh()
endfunction

" Resizing a `:term` window currently leads to scrollback text clipping, see https://github.com/neovim/neovim/issues/4997
function TerminaFoldSwitchView()
  if !exists("g:tfold_active") || bufnr() != s:bufterm &&  bufnr() != s:bufmirror
    echoerr("TerminaFold not initialized or wrong buffer")
    return
  endif
  if &buftype ==# 'terminal'
    call TerminafoldRefresh()
    exe 'tabn ' . s:tabmirror
  else
    " `feekdeys()` only adds the keys in the queue but doesn't execute what is typed before another input is made,
    " (which makes in our case the `<plug>StopSearchHighlight` be executed after the `norm 1gti` and thus inside Terminal Mode)
    " unless if using 'x' mode, but when trying to use it, disabling the highlight in the mapping doesn't work for unknown reasons
    " See: https://vimways.org/2019/a-test-to-attest-to/
    silent call feedkeys("\<plug>StopSearchHighlight", 'm')
    exe 'tabn ' . s:tabterm
    norm i
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

