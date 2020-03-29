" NOTE: You must, of course, install ag / the_silver_searcher
"
" Variables required to manage async
let s:job_number = 0
let s:toLocList = 0
let s:args = ''
let s:cwd = getcwd()
let s:data = ['']
let s:resetData = 1

"-----------------------------------------------------------------------------
" Public API
"-----------------------------------------------------------------------------

function! ag#Ag(cmd, ...) abort
  if empty(a:000)
    let l:args = [expand('<cword>')]
  els
  " If no pattern is provided, search for the word under the cursor
    let l:args = a:000
  end

  " Format, used to manage column jump
  if index(l:args, '-g') >= 0
    let s:ag_current_format = '%f'
  else
    let s:ag_current_format = g:ag_format
  endif

  " Set the script variables that will later be used by the async callback
  if a:cmd =~# '^l'
    let s:toLocList = 1
  else
    let s:toLocList = 0
  endif

  " Store the backups
  let l:t_ti_bak = &t_ti
  let l:t_te_bak = &t_te

  " Try to change all the system variables and run ag in the right folder
  try
    set t_ti=                      " These 2 commands make ag.vim not bleed in terminal
    set t_te=
    if g:ag_working_path_mode ==? 'r' " Try to find the project root for current buffer
      let l:cwd = s:guessProjectRoot()
      call s:execAg(l:args,  { 'cwd': l:cwd})
    else " Someone chose an undefined value or 'c' so we revert to searching in the cwd
      call s:execAg(l:args, {})
    endif
  finally
    let &t_ti = l:t_ti_bak
    let &t_te = l:t_te_bak
  endtry
endfunction

function! ag#AgBuffer(...) abort
  let l:bufs = filter(range(1, bufnr('$')), 'buflisted(v:val)')
  let l:files = []
  for buf in l:bufs
    let l:file = fnamemodify(bufname(buf), ':p')
    if !isdirectory(l:file)
      call add(l:files, l:file)
    endif
  endfor
  
  let l:args = a:000 + l:files
  call call(function('ag#Ag'), l:args)
endfunction

function! ag#AgFile(cmd, ...) abort
  let l:args = [cmd, '-g'] + a:000
  call call(function('ag#Ag'), l:args)
endfunction

function! ag#AgAdd(...) abort
  let s:resetData = 0
  call call(function('ag#Ag'), a:000)
endfunction

"-----------------------------------------------------------------------------
" Private API
"-----------------------------------------------------------------------------

function! s:handleOutput() abort
  if s:toLocList
    let l:match_count = len(getloclist(winnr()))
  else
    let l:match_count = len(getqflist())
  endif

  if l:match_count
    if s:toLocList
      exe g:ag_lhandler
      let l:apply_mappings = g:ag_apply_lmappings
      let l:matches_window_prefix = 'l' " we're using the location list
    else
      exe g:ag_qhandler
      let l:apply_mappings = g:ag_apply_qmappings
      let l:matches_window_prefix = 'c' " we're using the quickfix window
    endif

    " If highlighting is on, highlight the search keyword.
    if exists('g:ag_highlight')
      let @/ = matchstr(s:args, "\\v(-)\@<!(\<)\@<=\\w+|['\"]\\zs.{-}\\ze['\"]")
      call feedkeys(":let &hlsearch=1 \| echo \<CR>", 'n')
    end

    redraw! " Regular vim needs some1 to tell it to redraw

    if l:apply_mappings
      nnoremap <buffer> <silent> h  <C-W><CR>:exe 'wincmd ' (&splitbelow ? 'J' : 'K')<CR><C-W>p<C-W>J<C-W>p
      nnoremap <buffer> <silent> H  <C-W><CR>:exe 'wincmd ' (&splitbelow ? 'J' : 'K')<CR><C-W>p<C-W>J
      nnoremap <buffer> <silent> o  <CR>
      nnoremap <buffer> <silent> t  <C-W><CR><C-W>T
      nnoremap <buffer> <silent> T  <C-W><CR><C-W>TgT<C-W><C-W>
      nnoremap <buffer> <silent> v  <C-W><CR>:exe 'wincmd ' (&splitright ? 'L' : 'H')<CR><C-W>p<C-W>J<C-W>p

      let l:closecmd = l:matches_window_prefix . 'close'
      let l:opencmd = l:matches_window_prefix . 'open'

      exe 'nnoremap <buffer> <silent> e <CR><C-W><C-W>:' . l:closecmd . '<CR>'
      exe 'nnoremap <buffer> <silent> go <CR>:' . l:opencmd . '<CR>'
      exe 'nnoremap <buffer> <silent> q :' . l:closecmd . '<CR>'

      exe 'nnoremap <buffer> <silent> gv :call <SID>PreviewVertical("' . l:opencmd . '")<CR>'

      if g:ag_mapping_message && l:apply_mappings
        echom 'ag.nvim keys: q=quit <cr>/e/t/h/v=enter/edit/tab/split/vsplit go/T/H/gv=preview versions of same'
      endif
    endif
  else
    echom "No matches for '".s:args."'"
  endif
endfunction

function! s:handleAsyncOutput(job_id, data, event) abort
  " Don't care about older async calls that have been killed or replaced
  if s:job_number !=# a:job_id
    return
  end

  " Store all the input we get from the shell
  if a:event ==# 'stdout'
    let s:data[-1] .= a:data[0]
    call extend(s:data, a:data[1:])

  " When the program has finished running we parse the data
  elseif a:event ==# 'exit'
    echom 'Ag search finished'
    let l:expandeddata = []
    " Expand the path of the result so we can jump to it
    for l:result in s:data
      " At the end we usually have some bogous/empty lines, so skip them
      if( l:result =~ '^\s*$')
        continue
      endif
      if( l:result !~? '^/' ) " Only expand when the path is not a full path already
        let l:result = s:cwd.'/'.l:result
      endif
      let l:result = substitute(l:result , '//', '/' ,'g') " Get rid of excess slashes in filename if present
      call add(l:expandeddata, l:result)
    endfor

    if len(l:expandeddata) " Only if we actually find something
      let l:errorformat_bak = &errorformat
      let &errorformat = s:ag_current_format

      if s:toLocList
        " Add to location list
        lgete l:expandeddata
      else
        " Add to quickfix list
        cgete l:expandeddata
      endif
      let &errorformat = l:errorformat_bak
      call s:handleOutput()
    else
      echom 'No matches for "'.s:args.'"'
    endif
  endif
endfunction

function! s:execAg(args, opts) abort
  try
    call jobstop(s:job_number)
  catch
  endtry

  " Clear all of the old captures
  if s:resetData
    let s:data = ['']
  endif
  let s:resetData = 1

  let l:opts = { 
        \ 'on_stdout': function('s:handleAsyncOutput'),
        \ 'on_stderr': function('s:handleAsyncOutput'),
        \ 'on_exit': function('s:handleAsyncOutput')
        \ }

  let l:cmd = g:ag_prg + a:args
  let s:args = join(a:args, " ")

  echom 'Ag search started'
  let s:job_number = jobstart(l:cmd, extend(l:opts, a:opts))
endfunction


function! s:GetDocLocations() abort
  let dp = ''
  for p in split(&runtimepath,',')
    let p = p.'doc/'
    if isdirectory(p)
      let dp = p.'*.txt '.dp
    endif
  endfor
  return dp
endfunction

" Called from within a list window, preserves its height after shuffling vsplit.
" The parameter indicates whether list was opened as copen or lopen.
function! s:PreviewVertical(opencmd) abort
  let l:height = winheight(0)                 " Get the height of list window
  exec "normal! \<C-W>\<CR>"                | " Open current item in a new split
  exec 'wincmd ' (&splitright ? 'L' : 'H')  | " Slam newly opened window against the edge specified in vimrc
  exec a:opencmd                            | " Move back to the list window
  wincmd J                                    " Slam the list window against the bottom edge
  exec 'resize' l:height                    | " Restore the list window's height
endfunction

function! s:guessProjectRoot() abort
  let l:splitsearchdir = split(getcwd(), '/')

  while len(l:splitsearchdir) > 2
    let l:searchdir = '/'.join(l:splitsearchdir, '/').'/'
    for l:marker in ['.rootdir', '.git', '.hg', '.svn', 'bzr', '_darcs', 'build.xml']
      " found it! Return the dir
      if filereadable(l:searchdir.l:marker) || isdirectory(l:searchdir.l:marker)
        return l:searchdir
      endif
    endfor
    let l:splitsearchdir = l:splitsearchdir[0:-2] " Splice the list to get rid of the tail directory
  endwhile

  " Nothing found, fallback to current working dir
  return getcwd()
endfunction
