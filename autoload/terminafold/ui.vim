
" Prepare Search register in order to navigate between prompts
function! terminafold#ui#search_cells()
  norm! mm
  let @/ = g:tfold_cmdline_regex
  norm! `m
endfunction

" Define folding method to be used in TerminaFold mode
function! terminafold#ui#define_folding()
  " Fold all terminal command cells (output)
  " https://vi.stackexchange.com/questions/2165/folding-by-regex-search-pattern
  " COAI 8bfecd21-ffc2-4c12-ba13-bc63aaabf6d6
  function! s:FoldTermCells()
    " Get the current line content as a string
    let line_before = getline(v:lnum - 1)
    let line = getline(v:lnum)

    " Start fold only if current line is the first line after a prompt to
    " preserve syntax highlighting of prompt line (See https://github.com/nvim-treesitter/nvim-treesitter/issues/967 , https://stackoverflow.com/questions/45955033/how-to-keep-vims-folded-line-highlighted-as-the-syntax-of-the-first-line-of-the , https://stackoverflow.com/questions/1813060/syntax-highlighting-in-a-vim-fold-header)
    if line =~ g:tfold_cmdline_regex
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
  set foldexpr=s:FoldTermCells()
endfunction

function! terminafold#ui#define_highlights()
  " Highlight command lines in prompts
  " https://www.statox.fr/posts/2020/07/vim_flash_yanked_text/
  " Command Line
  hi CommandLine cterm=bold gui=bold ctermfg=12 guifg=#15aabf
  call matchadd('CommandLine', g:tfold_cmdline_regex)
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

function! terminafold#ui#define_signs()
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
  call sign_place(1, 'tfold', 'tfoldg', g:tfold_bufterm, {'lnum' : 1})
  call sign_place(2, 'tfold', 'tfoldt', g:tfold_bufterm, {'lnum' : 1})
  " Mirror Signs
  let g:tfold_signs_inited = 1
  call terminafold#ui#redefine_mirror_signs()
endfunction

function! terminafold#ui#redefine_mirror_signs()
  " Nvim deletes signs on lines that are deleted so
  " until we exceed the limit mentioned in NOTE1 we need to replace the signs in the mirror
  if !exists("g:tfold_signs_inited")
    return
  endif
  call sign_place(3, 'tfold', 'tfoldg', g:tfold_bufmirror, {'lnum' : 1})
  call sign_place(4, 'tfold', 'tfoldm', g:tfold_bufmirror, {'lnum' : 1})
endfunction

" Resizing a `:term` window currently leads to scrollback text clipping, see https://github.com/neovim/neovim/issues/4997
function terminafold#ui#siwtch_view()
  if !exists("g:tfold_active") || bufnr() != g:tfold_bufterm &&  bufnr() != g:tfold_bufmirror
    echoerr("TerminaFold not initialized or wrong buffer")
    return
  endif
  if &buftype ==# 'terminal'
    call terminafold#scrollback#refresh()
    exe 'tabn ' . g:tfold_tabmirror
  else
    " `feekdeys()` only adds the keys in the queue but doesn't execute what is typed before another input is made,
    " (which makes in our case the `<plug>StopSearchHighlight` be executed after the `norm 1gti` and thus inside Terminal Mode)
    " unless if using 'x' mode, but when trying to use it, disabling the highlight in the mapping doesn't work for unknown reasons
    " See: https://vimways.org/2019/a-test-to-attest-to/
    silent call feedkeys("\<plug>StopSearchHighlight", 'm')
    exe 'tabn ' . g:tfold_tabterm
    norm i
  endif
endfunction
