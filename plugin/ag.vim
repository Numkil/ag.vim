" NOTE: You must, of course, install ag / the_silver_searcher

if exists('g:autoloaded_ag')
  finish
endif

if !executable('rg')
  echoe "Ag command was not found. Is ripgrep installed?"
  finish
endif

" Location of the ag utility
if !exists('g:ag_prg')
  let g:ag_prg = ['rg','--follow', '--smart-case', '--vimgrep']
endif

if !exists('g:fd_prg')
  let g:fd_prg = ['fd','--follow']
endif

if !exists('g:fd_format')
  let g:fd_format = '%f'
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
command! -bang -nargs=* -complete=file AgBuffer call ag#AgBuffer('grep<bang>',<f-args>)
command! -bang -nargs=* -complete=file AgAdd call ag#AgAdd('grepadd<bang>', <f-args>)
command! -bang -nargs=* -complete=file LAg call ag#Ag('lgrep<bang>', <f-args>)
command! -bang -nargs=* -complete=file LAgBuffer call ag#AgBuffer('lgrep<bang>',<f-args>)
command! -bang -nargs=* -complete=file LAgAdd call ag#AgAdd('lgrepadd<bang>', <f-args>)
command! -bang -nargs=* -complete=file Fd call ag#Ag('find<bang>', <f-args>)
command AgAsArgs lua require("agvim").as_args()

let g:autoloaded_ag = 1
