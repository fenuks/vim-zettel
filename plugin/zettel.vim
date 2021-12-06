if exists('g:loaded_zettel') || &compatible
  finish
endif

let g:loaded_zettel = 1

" format of a new zettel filename
if !exists('g:zettel_format')
  let g:zettel_format = '%y%m%d-%H%M'
endif

" set default wiki number. it is set to -1 when no wiki is initialized
" we will set it to first wiki in wiki list, with number 0
function! s:setup_zettel_wikis() abort
  if exists('g:zettel_wikis_nr')
    return
  endif
  if exists('g:zettel_options')
    let g:zettel_wikis_nr = s:get_zettel_wiki_nr_from_options()
  else
    let g:zettel_wikis_nr = [0]
  endif
endfunction

" get the first non emtpy wiki idx from the options
function! s:get_zettel_wiki_nr_from_options() abort
  let l:zettel_wikis = []
  for i in range(len(g:zettel_options))
    if len(g:zettel_options[i]) > 0
      call add(l:zettel_wikis, i)
    endif
  endfor
  return l:zettel_wikis
endfunction

call s:setup_zettel_wikis()

" make fulltext search in all VimWiki files using FZF and insert link to the
" found file
command! -bang -nargs=* ZettelSearch call zettel#fzf#sink_onefile(<q-args>, 'zettel#fzf#wiki_search')

command! -bang -nargs=* ZettelYankName call zettel#vimwiki#wiki_yank_name()

" crate new zettel using command
command! -bang -count=0 -nargs=? ZettelNew call zettel#vimwiki#zettel_new(<q-args>, <count>)

command! -buffer ZettelGenerateLinks call zettel#vimwiki#generate_links()
command! -buffer -nargs=* -complete=custom,vimwiki#tags#complete_tags
      \ ZettelGenerateTags call zettel#vimwiki#generate_tags(<f-args>)

command! -buffer ZettelBackLinks call zettel#vimwiki#backlinks()
command! -buffer ZettelInbox call zettel#vimwiki#inbox()

nnoremap <silent> <Plug>ZettelSearchMap :ZettelSearch<CR>
nnoremap <silent> <Plug>ZettelYankNameMap :ZettelYankName<CR> 
nnoremap <silent> <Plug>ZettelReplaceFileWithLink :call zettel#vimwiki#replace_file_with_link()<CR> 
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

" gloabal commands
command! -nargs=? -bang ZettelCapture
      \ call zettel#vimwiki#zettel_capture(<q-args>)

" make fulltext search in all VimWiki files using FZF
" command! -bang -nargs=* ZettelSearch call fzf#vim#ag(<q-args>, 
command! -bang -nargs=* ZettelInsertNote call zettel#fzf#execute_fzf(<q-args>, 
      \'--skip-vcs-ignores', fzf#vim#with_preview({
      \'down': '~40%',
      \'sink*':function('zettel#fzf#insert_note'),
      \'dir': vimwiki#vars#get_wikilocal('path'),
      \'options':['--exact']}))

" make fulltext search in all VimWiki files using FZF and open the found file
command! -bang -nargs=* ZettelOpen call zettel#fzf#sink_onefile(<q-args>, 'zettel#fzf#search_open')
