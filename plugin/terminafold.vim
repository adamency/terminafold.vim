" ========== FOLDED TERMINAL: TerminaFold ==========

" Implements terminal sessions where scrollback is composed of
" collapsible/foldable cells containing the commands run and their outputs

let s:cmdline_regex = '\v^\S*\w+\@\w+.*:.*[$#]\s\zs.*'

" Prepare Search register in order to navigate between prompts
function! TerminaFoldSearchCells()
  norm! mm
  let @/ = s:cmdline_regex
  norm! `m
endfunction

function! TerminaFoldGet2ndPrompt()
    call cursor(1,1)
    let _ = search(s:cmdline_regex, 'W')
    let s:matchline_current = search(s:cmdline_regex, 'W')
    " We only want to copy up to the line before the 2nd prompt as it can be the currently
    " active prompt in which case that line will change when the user inputs a command
    let s:last_line_to_copy = s:matchline_current - 1
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

    call TerminafoldDefineFolding()
    call TerminafoldDefineHighlights()
    call TerminafoldDefineSigns()
    " Set up browsing between cells with `n` & `N`
    call TerminaFoldSearchCells()

    " Prevent modifications of mirror buffer outside of TerminaFold
    setlocal nomodifiable
    " Go back to term
    exe 'tabn ' . s:tabterm

    """ Set Automatic Refresh Policy
    let g:tfold_timer_active = 0
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

function! TerminafoldInit()
  if !exists("g:tfold_active")
    return
  endif

  let currentbuf = bufnr()
  let currenttab = tabpagenr()
  exe 'tabn ' . s:tabmirror
  let currentbufmirrortab = bufnr()

  " Copy term buffer content
  exe 'b' . s:bufterm
  " Ensure we will copy at least one line of the terminal to prevent copying before the terminal has finished starting
  " or otherwise the line comparison for the refresh < 100 will fail
  call TerminaFoldGet2ndPrompt()
  if s:matchline_current > 0
    let range = 1 . ',' . s:last_line_to_copy
    silent execute range . 'yank'
    exe 'b' . s:bufmirror
    setlocal modifiable
    silent execute 1 . 'put'
    " Remove first empty line
    1d
    setlocal nomodifiable
    " Save current terminal EOF for next refresh
    let g:tfold_mirror_end = line('$')

    " Post-processing in bufmirror
    exe 'b' . s:bufmirror
    let g:tfold_mirror_end = line('$')
    call TerminaFoldSearchCells()
    let g:tfold_inited = 1
    echom "Initialized TerminaFold Mirror (" . g:tfold_mirror_end . " lines)"
  endif

  " Go back to current buffer
  exe 'b' . currentbufmirrortab
  exe 'tabn ' . currenttab
  exe 'b' . currentbuf
endfunction

function! TerminafoldRefresh()
  if !exists("g:tfold_active") || !exists("g:tfold_inited")
    return
  endif

  let currentbuf = bufnr()
  let currenttab = tabpagenr()
  exe 'tabn ' . s:tabmirror
  let currentbufmirrortab = bufnr()

  " Get Last mirrored line
  exe 'b' . s:bufmirror
  let last_mirrored_line_content = getline(g:tfold_mirror_end)
  let init_last_mirror_line_content = getline(s:last_line_to_copy)

  exe 'b' . s:bufterm
  " If we don't run infinity early enough, i.e. before reading
  " Vim's scrollback limit the normal copy&append method would think
  " no new lines have come since theviewport would be the same size, but
  " Infinity makes a search on the whole buffer so we run it as late as possible
  if g:tfold_mirror_end > 90000
    call TerminafoldRefreshInfinity(last_mirrored_line_content)
  else
  " Retrieve new scrollback only from end of last refresh for better performance on big scrollbacks
  let last_term_line = line('$') - 1
  let new_lines_count = last_term_line - g:tfold_mirror_end 
  " NOTE1: At start the `:terminal` buffer is filled with empty lines until the end
  " of the screen, so the scrollback history will not match between command runs until a full
  " screen of scrollback has been filled and copied to the mirror (current screen size: 53 lines)
  " As we thus can't know the difference before this threshold, we replace the entire buffer until attained
  " Also check if we are not in a TUI by comparing the buffers (each line mirrored should be exactly the same as the same line on the term)
  if g:tfold_mirror_end < 100 && getline(s:last_line_to_copy) != init_last_mirror_line_content
    :
  elseif g:tfold_mirror_end < 100 && getline(s:last_line_to_copy) == init_last_mirror_line_content
    " Replace mirror by full term content (small scrollback here so not a problem)
    silent %y
    exe 'b' . s:bufmirror
    setlocal modifiable
    let curl = line('.')
    " Delete old content into black hole register to keep previously copied term content
    norm gg"_dGpggddGdd
    exe curl
    call TerminafoldRedefineMirrorSigns()
    setlocal nomodifiable
    echom "Refreshed TerminaFold Mirror (" . last_term_line . " lines)"
  " If term content has been added (also check that scrollback are equal to prevent mirroring when a TUI program is opened)
  elseif new_lines_count == 0
    :
  " If we ran a command with more than 50k lines of output, normal refresh would fail,
  " so we try RefreshInfinity
  elseif new_lines_count > 0 && getline(g:tfold_mirror_end) != last_mirrored_line_content && g:tfold_mirror_end > 50000
    call TerminafoldRefreshInfinity(last_mirrored_line_content)
  elseif new_lines_count > 0 && getline(g:tfold_mirror_end) == last_mirrored_line_content
    " Copy & Append Remaining Scrollback to mirror buffer
    let range = g:tfold_mirror_end + 1 . ',' . last_term_line
    silent execute range . 'yank'
    exe 'b' . s:bufmirror
    setlocal modifiable
    let start_put_line = g:tfold_mirror_end
    silent execute start_put_line . 'put'
    setlocal nomodifiable
    echom "Refreshed TerminaFold Mirror (" . new_lines_count . " more lines)"
  else
    echoerr("SHOULD I HAVE PASSED HERE?")
    " If var name is full caps, `!` option of `'shada'` will save that var persistently
    let g:tfold_SHUTDOWN = 1
  endif
  endif

  " Post-processing in bufmirror
  exe 'b' . s:bufmirror
  let g:tfold_mirror_end = line('$')
  call TerminaFoldSearchCells()

  " Go back to current buffer
  exe 'b' . currentbufmirrortab
  exe 'tabn ' . currenttab
  exe 'b' . currentbuf
endfunction

function! TerminafoldRefreshInfinity(last_mirrored_line_content)
  if !exists("g:tfold_active") || &buftype !=# 'terminal' || g:tfold_mirror_end <= 50000
    echoerr "LOCKED"
    return
  endif

  " Find last line that match exactly with the last mirrored line
  "normal G$ " Error: 'can't re-enter Normal mode from Terminal mode'
  call cursor(line('$'),99999)
  let [matchline, matchcol] = searchpos(a:last_mirrored_line_content, 'bcz')

  " Check that there is a match &
  " that the match is the same line or above (cause if not,
  "   it could only logically be a future command) &
  " that the two line totals are different (if mirror is bigger,
  "   we are in overload mode, so the comparison is impossible now and
  "   if mirror is smaller, then we still haven't passed Vim's scrollback limit
  "   as 
  let last_term_line = line('$') - 1
  echom "g:tfold_mirror_end " . g:tfold_mirror_end
  echom "last_term_line " . last_term_line
  echom "matchline " . matchline
  let range = matchline + 1 . ',' . last_term_line
  echom "range " . range
  if matchline != 0 && g:tfold_mirror_end == matchline && g:tfold_mirror_end == last_term_line
    :
  elseif matchline != 0 && (g:tfold_mirror_end > matchline || (g:tfold_mirror_end == matchline && last_term_line > g:tfold_mirror_end))
    " Copy & Append Remaining Scrollback to mirror buffer
    silent execute range . 'yank'
    exe 'b' . s:bufmirror
    echom "g:tfold ACTUAL _mirror_end " . line('$')
    setlocal modifiable
    let start_put_line = g:tfold_mirror_end
    silent execute start_put_line . 'put'
    setlocal nomodifiable
    echom "(INFINITY) Refreshed TerminaFold Mirror (" . (last_term_line - matchline) . " more lines)"
  else
    echom "(INFINITY) TerminaFold Refresh Error: Scrollback CORRUPTED"
    let g:tfold_SHUTDOWN = 1
  endif
endfunction

function! TerminafoldRefreshFromTimer(timer)
  " Only allow one active refresh from timer at a time &
  " disable auto-refresh if we think there is scrollback corruption
  " or we are already on the mirror to prevent flickering < 100L because of depleting the buffer
  if g:tfold_timer_active == 1 || exists('g:tfold_SHUTDOWN') || bufnr() == s:bufmirror
    return
  endif
  let g:tfold_timer_active = 1
  if !exists('g:tfold_inited')
    echom "Tiggering INIT"
    call TerminafoldInit()
    let g:tfold_timer_active = 0
    return
  endif
  try
    echom "Tiggering REFRESH"
    call TerminafoldRefresh()
  finally
    let g:tfold_timer_active = 0
  endtry
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

