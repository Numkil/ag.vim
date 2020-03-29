" NOTE: You must, of course, install ag / the_silver_searcher

if exists('g:autoloaded_ag')
  finish
endif

if !executable('ag')
  echoe "Ag command was not found. Is the silver searcher installed and on your $PATH?"
  finish
endif

" Location of the ag utility
if !exists('g:ag_prg')
  let g:ag_prg = ['ag','--vimgrep','--silent']
endif

if !exists('g:ag_format')
  let g:ag_format = '%f:%l:%c:%m'
endif

if !exists('g:ag_apply_qmappings')
  let g:ag_apply_qmappings = 1
endif

if !exists('g:ag_apply_lmappings')
  let g:ag_apply_lmappings = 1
endif

if !exists('g:ag_qhandler')
  let g:ag_qhandler = 'botright copen'
endif

if !exists('g:ag_lhandler')
  let g:ag_lhandler = 'botright lopen'
endif

if !exists('g:ag_highlight')
  let g:ag_highlight = 0
endif

if !exists('g:ag_mapping_message')
  let g:ag_mapping_message = 1
endif

if !exists('g:ag_working_path_mode')
    let g:ag_working_path_mode = 'c'
endif

command! -bang -nargs=* -complete=file Ag call ag#Ag('grep<bang>',<f-args>)
command! -bang -nargs=* -complete=file AgBuffer call ag#AgBuffer('grep<bang>',<q-args>)
command! -bang -nargs=* -complete=file AgAdd call ag#AgAdd('grepadd<bang>', <q-args>)
command! -bang -nargs=* -complete=file AgFromSearch call ag#AgFromSearch('grep<bang>', <q-args>)
command! -bang -nargs=* -complete=file LAg call ag#Ag('lgrep<bang>', <q-args>)
command! -bang -nargs=* -complete=file LAgBuffer call ag#AgBuffer('lgrep<bang>',<q-args>)
command! -bang -nargs=* -complete=file LAgAdd call ag#AgAdd('lgrepadd<bang>', <q-args>)
command! -bang -nargs=* -complete=file AgFile call ag#AgFile('grep<bang>', <q-args>)
command! -bang -nargs=* -complete=help AgHelp call ag#AgHelp('grep<bang>',<q-args>)
command! -bang -nargs=* -complete=help LAgHelp call ag#AgHelp('lgrep<bang>',<q-args>)

let g:autoloaded_ag = 1
