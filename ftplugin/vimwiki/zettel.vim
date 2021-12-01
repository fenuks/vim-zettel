" format of a new zettel filename
if !exists('g:zettel_format')
  let g:zettel_format = '%y%m%d-%H%M'
endif

function! s:wiki_yank_name()
  let l:filename = expand('%')
  let l:link = zettel#vimwiki#get_link(l:filename)
  let l:clipboardtype = &clipboard
  if l:clipboardtype ==# 'unnamed'
    let @* = link
  elseif clipboardtype ==# 'unnamedplus'
    let @+ = link
  else
    let @@ = link
  endif
  return link
endfunction

" replace file name under cursor which corresponds to a wiki file with a
" corresponding Wiki link
function! s:replace_file_with_link()
  let l:filename = expand('<cfile>')
  let l:link = zettel#vimwiki#get_link(l:filename)
  execute 'normal BvExa' . link
endfunction

" make fulltext search in all VimWiki files using FZF and insert link to the
" found file
command! -bang -nargs=* ZettelSearch call zettel#fzf#sink_onefile(<q-args>, 'zettel#fzf#wiki_search')

command! -bang -nargs=* ZettelYankName call <sid>wiki_yank_name()

" crate new zettel using command
command! -bang -nargs=* ZettelNew call zettel#vimwiki#zettel_new(<q-args>)

command! -buffer ZettelGenerateLinks call zettel#vimwiki#generate_links()
command! -buffer -nargs=* -complete=custom,vimwiki#tags#complete_tags
      \ ZettelGenerateTags call zettel#vimwiki#generate_tags(<f-args>)

command! -buffer ZettelBackLinks call zettel#vimwiki#backlinks()
command! -buffer ZettelInbox call zettel#vimwiki#inbox()

nnoremap <silent> <Plug>ZettelSearchMap :ZettelSearch<CR>
nnoremap <silent> <Plug>ZettelYankNameMap :ZettelYankName<CR> 
nnoremap <silent> <Plug>ZettelReplaceFileWithLink :call <sid>replace_file_with_link()<CR> 
xnoremap <silent> <Plug>ZettelNewSelectedMap :call zettel#vimwiki#zettel_new_selected()<CR>

if !exists('g:zettel_default_mappings')
  let g:zettel_default_mappings=1
endif

if g:zettel_default_mappings == 1
  imap <buffer> <silent> [[ [[<esc><Plug>ZettelSearchMap
  nmap <buffer> T <Plug>ZettelYankNameMap
  xmap <buffer> z <Plug>ZettelNewSelectedMap
  nmap <buffer> gZ <Plug>ZettelReplaceFileWithLink
endif
