
function! s:TerminaFoldGet2ndPrompt()
    call cursor(1,1)
    let _ = search(g:tfold_cmdline_regex, 'W')
    let s:matchline_current = search(g:tfold_cmdline_regex, 'W')
    " We only want to copy up to the line before the 2nd prompt as it can be the currently
    " active prompt in which case that line will change when the user inputs a command
    let s:last_line_to_copy = s:matchline_current - 1
endfunction

" First scrollback copy
function! terminafold#scrollback#init()
  if !exists("g:tfold_active")
    return
  endif

  let currentbuf = bufnr()
  let currenttab = tabpagenr()
  exe 'tabn ' . g:tfold_tabmirror
  let currentbufmirrortab = bufnr()

  " Copy term buffer content
  exe 'b' . g:tfold_bufterm
  " Ensure we will copy at least one line of the terminal to prevent copying before the terminal has finished starting
  " or otherwise the line comparison for the refresh < 100 will fail
  call s:TerminaFoldGet2ndPrompt()
  if s:matchline_current > 0
    let range = 1 . ',' . s:last_line_to_copy
    silent execute range . 'yank'
    exe 'b' . g:tfold_bufmirror
    setlocal modifiable
    silent execute 1 . 'put'
    " Remove first empty line
    1d
    setlocal nomodifiable
    " Save current terminal EOF for next refresh
    let g:tfold_mirror_end = line('$')

    " Post-processing in bufmirror
    exe 'b' . g:tfold_bufmirror
    let g:tfold_mirror_end = line('$')
    call terminafold#ui#search_cells()
    let g:tfold_inited = 1
    echom "Initialized TerminaFold Mirror (" . g:tfold_mirror_end . " lines)"
  endif

  " Go back to current buffer
  exe 'b' . currentbufmirrortab
  exe 'tabn ' . currenttab
  exe 'b' . currentbuf
endfunction

" Scrollback < screen size
function! terminafold#scrollback#refresh_small()
  if !exists("g:tfold_active") || !exists("g:tfold_inited")
    return
  endif

  " NOTE1: At start the `:terminal` buffer is filled with empty lines until the end
  " of the screen, so the scrollback history will not match between command runs until a full
  " screen of scrollback has been filled and copied to the mirror (current screen size: 53 lines)
  " We thus can't know the difference before this threshold => we replace the entire buffer until threshold reached

  let init_last_mirror_line_content = getline(s:last_line_to_copy)

  " Also check if we are not in a TUI by comparing the buffers (each line mirrored should be exactly the same as the same line on the term)
  if getline(s:last_line_to_copy) != init_last_mirror_line_content
    :
  elseif getline(s:last_line_to_copy) == init_last_mirror_line_content
    " Replace mirror by full term content (small scrollback here so not a problem)
    silent %y
    exe 'b' . g:tfold_bufmirror
    setlocal modifiable
    let curl = line('.')
    " Delete old content into black hole register to keep previously copied term content
    norm gg"_dGpggddGdd
    exe curl
    call terminafold#ui#redefine_mirror_signs()
    setlocal nomodifiable
    echom "Refreshed TerminaFold Mirror (" . s:last_term_line . " lines)"
  endif
endfunction

" screen size <= Scrollback < Vim scrollback limit
function! terminafold#scrollback#refresh_medium(last_mirrored_line_content)
  " Retrieve new scrollback only from end of last refresh for better performance on big scrollbacks
  let new_lines_count = s:last_term_line - g:tfold_mirror_end 

  if new_lines_count == 0
    :
  " If we ran a command with more than 50k lines of output, normal refresh would fail, so we try RefreshInfinity
  elseif new_lines_count > 0 && getline(g:tfold_mirror_end) != a:last_mirrored_line_content && g:tfold_mirror_end > 50000
    call terminafold#scrollback#refreshInfinity(a:last_mirrored_line_content)
  " If term content has been added (also check that scrollback are equal to prevent mirroring when a TUI program is opened)
  elseif new_lines_count > 0 && getline(g:tfold_mirror_end) == a:last_mirrored_line_content
    " Copy & Append Remaining Scrollback to mirror buffer
    let range = g:tfold_mirror_end + 1 . ',' . s:last_term_line
    silent execute range . 'yank'
    exe 'b' . g:tfold_bufmirror
    setlocal modifiable
    let start_put_line = g:tfold_mirror_end
    silent execute start_put_line . 'put'
    setlocal nomodifiable
    echom "Refreshed TerminaFold Mirror (" . new_lines_count . " more lines)"
  else
    echom("new_lines_count: " . new_lines_count)
    echom("getline(g:tfold_mirror_end): " . getline(g:tfold_mirror_end))
    echom("a:last_mirrored_line_content: " . a:last_mirrored_line_content)
    echoerr("SHOULD I HAVE PASSED HERE?")
    " If var name is full caps, `!` option of `'shada'` will save that var persistently
    let g:tfold_SHUTDOWN = 1
  endif
endfunction

function! terminafold#scrollback#refresh()
  if !exists("g:tfold_active") || !exists("g:tfold_inited")
    return
  endif

  let currentbuf = bufnr()
  let currenttab = tabpagenr()
  exe 'tabn ' . g:tfold_tabmirror
  let currentbufmirrortab = bufnr()

  " Get Last mirrored line
  exe 'b' . g:tfold_bufmirror
  let last_mirrored_line_content = getline(g:tfold_mirror_end)

  exe 'b' . g:tfold_bufterm
  let s:last_term_line = line('$') - 1

  if g:tfold_mirror_end < 100
    call terminafold#scrollback#refresh_small()
  " If we don't run infinity early enough, i.e. before reaching
  " Vim's scrollback limit the normal copy&append method would think
  " no new lines have come since theviewport would be the same size, but
  " Infinity makes a search on the whole buffer so we run it as late as possible
  elseif g:tfold_mirror_end > 90000
    call terminafold#scrollback#refreshInfinity(last_mirrored_line_content)
  else
    call terminafold#scrollback#refresh_medium(last_mirrored_line_content)
  endif

  " Post-processing in bufmirror
  exe 'b' . g:tfold_bufmirror
  let g:tfold_mirror_end = line('$')
  call terminafold#ui#search_cells()

  " Go back to current buffer
  exe 'b' . currentbufmirrortab
  exe 'tabn ' . currenttab
  exe 'b' . currentbuf
endfunction

" Scrollback >= Vim scrollback limit
function! terminafold#scrollback#refreshInfinity(last_mirrored_line_content)
  if !exists("g:tfold_active") || &buftype !=# 'terminal' || g:tfold_mirror_end <= 50000
    echoerr "LOCKED"
    return
  endif

  " Find last line that match exactly with the last mirrored line
  "normal G$ " Error: 'can't re-enter Normal mode from Terminal mode'
  call cursor(line('$'),99999)
  let [matchline, matchcol] = searchpos(a:last_mirrored_line_content, 'bcz')

  echom "g:tfold_mirror_end " . g:tfold_mirror_end
  echom "s:last_term_line " . s:last_term_line
  echom "matchline " . matchline
  let range = matchline + 1 . ',' . s:last_term_line
  echom "range " . range

  " Logic explanation: logic/refresh-infinity.decision-tree.txt
  if matchline != 0 && g:tfold_mirror_end == matchline && g:tfold_mirror_end == s:last_term_line
    :
  elseif matchline != 0 && (g:tfold_mirror_end > matchline || (g:tfold_mirror_end == matchline && s:last_term_line > g:tfold_mirror_end))
    " Copy & Append Remaining Scrollback to mirror buffer
    silent execute range . 'yank'
    exe 'b' . g:tfold_bufmirror
    echom "g:tfold ACTUAL _mirror_end " . line('$')
    setlocal modifiable
    let start_put_line = g:tfold_mirror_end
    silent execute start_put_line . 'put'
    setlocal nomodifiable
    echom "(INFINITY) Refreshed TerminaFold Mirror (" . (s:last_term_line - matchline) . " more lines)"
  else
    echom "(INFINITY) TerminaFold Refresh Error: Scrollback CORRUPTED"
    let g:tfold_SHUTDOWN = 1
  endif
endfunction

function! terminafold#scrollback#refreshFromTimer(timer)
  " Only allow one active refresh from timer at a time &
  " disable auto-refresh if we think there is scrollback corruption
  " or we are already on the mirror to prevent flickering < 100L because of depleting the buffer
  if g:tfold_timer_active == 1 || exists('g:tfold_SHUTDOWN') || bufnr() == g:tfold_bufmirror
    return
  endif
  let g:tfold_timer_active = 1
  if !exists('g:tfold_inited')
    echom "Triggering INIT"
    call terminafold#scrollback#init()
    let g:tfold_timer_active = 0
    return
  endif
  try
    echom "Triggering REFRESH"
    call terminafold#scrollback#refresh()
  finally
    let g:tfold_timer_active = 0
  endtry
endfunction

