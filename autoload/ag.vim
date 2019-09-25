" NOTE: You must, of course, install ag / the_silver_searcher
"
" Variables required to manage async
let s:job_number = 0
let s:locListCommand = 0
let s:args = ''
let s:cwd = getcwd()
let s:data = []
let s:resetData = 1

"-----------------------------------------------------------------------------
" Public API
"-----------------------------------------------------------------------------

function! ag#Ag(cmd, args) abort
  let l:ag_executable = get(split(g:ag_prg, ' '), 0)

  " Ensure that `ag` is installed
  if !executable(l:ag_executable)
    echoe "Ag command '" . l:ag_executable . "' was not found. Is the silver searcher installed and on your $PATH?"
    return
  endif

  " If no pattern is provided, search for the word under the cursor
  if empty(a:args)
    let l:grepargs = expand('<cword>')
  else
    let l:grepargs = a:args . join(a:000, ' ')
  end

  if empty(l:grepargs)
    echo "Usage: ':Ag {pattern}'. See ':help :Ag' for more information."
    return
  endif

  " Format, used to manage column jump
  if a:args =~# '-g'
    let s:ag_format_backup = g:ag_format
    let g:ag_format = '%f'
  elseif exists('s:ag_format_backup')
    let g:ag_format = s:ag_format_backup
  endif

  " Set the script variables that will later be used by the async callback
  let s:args = l:grepargs
  let l:cmd = a:cmd . ' ' . escape(l:grepargs, '|')
  if l:cmd =~# '^l'
    let s:locListCommand = 1
  else
    let s:locListCommand = 0
  endif

  " Store the backups
  let l:t_ti_bak = &t_ti
  let l:t_te_bak = &t_te

  " Try to change all the system variables and run ag in the right folder
  try
    set t_ti=                      " These 2 commands make ag.vim not bleed in terminal
    set t_te=
    if g:ag_working_path_mode ==? 'r' " Try to find the project root for current buffer
      let l:cwd_back = getcwd()
      let s:cwd = s:guessProjectRoot()
      try
        exe 'lcd '.s:cwd
      catch
      finally
        call s:executeCmd(l:grepargs, l:cmd)
        exe 'lcd '.l:cwd_back
      endtry
    else " Someone chose an undefined value or 'c' so we revert to searching in the cwd
      call s:executeCmd(l:grepargs, l:cmd)
    endif
  finally
    let &t_ti = l:t_ti_bak
    let &t_te = l:t_te_bak
  endtry

  " No neovim, when we finally get here we already have the output so run handleOutput
  if !has('nvim')
    call s:handleOutput()
    return
  endif
endfunction

function! ag#AgBuffer(cmd, args) abort
  let l:bufs = filter(range(1, bufnr('$')), 'buflisted(v:val)')
  let l:files = []
  for buf in l:bufs
    let l:file = fnamemodify(bufname(buf), ':p')
    if !isdirectory(l:file)
      call add(l:files, l:file)
    endif
  endfor
  call ag#Ag(a:cmd, a:args . ' ' . join(l:files, ' '))
endfunction

function! ag#AgFromSearch(cmd, args) abort
  let l:search =  getreg('/')
  " translate vim regular expression to perl regular expression.
  let l:search = substitute(l:search,'\(\\<\|\\>\)','\\b','g')
  call ag#Ag(a:cmd, '"' .  l:search .'" '. a:args)
endfunction

function! ag#AgHelp(cmd,args) abort
  let l:args = a:args.' '.s:GetDocLocations()
  call ag#Ag(a:cmd,l:args)
endfunction

function! ag#AgFile(cmd, args) abort
  let l:args = ' -g ' . a:args
  call ag#Ag(a:cmd, l:args)
endfunction

function! ag#AgAdd(cmd, args) abort
  let s:resetData = 0
  call ag#Ag(a:cmd, a:args)
endfunction

"-----------------------------------------------------------------------------
" Private API
"-----------------------------------------------------------------------------

function! s:handleOutput() abort
  if s:locListCommand
    let l:match_count = len(getloclist(winnr()))
  else
    let l:match_count = len(getqflist())
  endif

  if l:match_count
    if s:locListCommand
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
    let s:data = s:data+a:data

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
      let &errorformat = g:ag_format

      if s:locListCommand
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

function! s:executeCmd(grepargs, cmd) abort
  if !has('nvim')
    silent! execute a:cmd
    return
  endif

  " Stop older running ag jobs if any
  try
    call jobstop(s:job_number)
  catch
  endtry

  " Clear all of the old captures
  if s:resetData
    let s:data = []
  endif
  let s:resetData = 1

  " All types of exiting the job should be directed to handleAsyncOutput
  let s:callbacks = {
  \ 'on_stdout': function('s:handleAsyncOutput'),
  \ 'on_stderr': function('s:handleAsyncOutput'),
  \ 'on_exit': function('s:handleAsyncOutput')
  \ }

  let l:splitargs = split(a:grepargs)
  let l:grepargs = ''
  "Make sure we shellescape arguments separately and expand the ~ in a string
  for l:splitarg in l:splitargs
    if l:splitarg !~? '^-'
        let l:grepargs = l:grepargs.' '.shellescape(substitute(l:splitarg,'^\~',$HOME, ''))
    else
        let l:grepargs = l:grepargs.' '.l:splitarg
    endif
  endfor

  " Construct the command string send to job shell -
  " cd [directory]; ag --vimgrep [extra flags] '[value]' '[optional directory]'
  let l:agcmd = 'cd '.s:cwd.'; '.g:ag_prg . ' ' .  l:grepargs

  echom 'Ag search started'
  let s:job_number = jobstart(['sh', '-c', l:agcmd], extend({'shell': 'shell 1'}, s:callbacks))
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
