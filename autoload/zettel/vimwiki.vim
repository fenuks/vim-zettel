" user configurable fields that should be inserted to a front matter of a new
" Zettel
if !exists('g:zettel_front_matter')
  let g:zettel_front_matter = {}
endif

" front matter can be disabled using disable_front_matter local wiki option
if !exists('g:zettel_disable_front_matter')
  let g:zettel_disable_front_matter=0
end

if !exists('g:zettel_generated_index_title')
  let g:zettel_generated_index_title = "Generated Index"
endif
if !exists('g:zettel_generated_index_title_level')
  let g:zettel_generated_index_title_level = 1
endif

if !exists('g:zettel_backlinks_title')
  let g:zettel_backlinks_title = "Backlinks"
endif
if !exists('g:zettel_backlinks_title_level')
  let g:zettel_backlinks_title_level = 1
endif

if !exists('g:zettel_unlinked_notes_title')
  let g:zettel_unlinked_notes_title = "Unlinked Notes"
endif
if !exists('g:zettel_unlinked_notes_title_level')
  let g:zettel_unlinked_notes_title_level = 1
endif

if !exists('g:zettel_generated_tags_title')
  let g:zettel_generated_tags_title = "Generated Tags"
endif
if !exists('g:zettel_generated_tags_title_level')
  let g:zettel_generated_tags_title_level = 1
endif

" default title used for %title placeholder in g:zettel_format if the title is
" empty
if !exists('g:zettel_default_title')
  let g:zettel_default_title="untitled"
endif

" number of random characters used in %random placehoder in new zettel name
if !exists('g:zettel_random_chars')
  let g:zettel_random_chars=8
endif

" default date format used in front matter for new zettel
if !exists('g:zettel_date_format')
  let g:zettel_date_format = "%Y-%m-%d %H:%M"
endif

" initialize new zettel date. it should be overwritten in zettel#vimwiki#create()
let s:zettel_date = strftime(g:zettel_date_format)


let s:markdown_syntax = {
\ 'link_format': "[%title](%link)",
\ 'header_format': "%s: %s",
\ 'header_delimiter': "---",
\ 'insert_mode_title_format': "``l",
\ 'grep_link_pattern': '/\(%s\.\{-}m\{-}d\{-}\)/',
\ 'section_pattern': "# %s",
\}

if exists("g:vimwiki_markdown_link_ext") && g:vimwiki_markdown_link_ext == 1
    let g:markdown_syntax.link_format = "[%title](%link.md)"
endif

let s:vimwiki_syntax = {
\  'link_format': "[[%link|%title]]",
\  'header_format': "%%%s %s",
\  'header_delimiter': "",
\  'insert_mode_title_format': "h",
\  'grep_link_pattern': '/\[%s[|#\]]/',
\  'section_pattern': "= %s =",
\}

let s:tag_pattern = '^!_TAG'

if exists("g:zettel_link_format")
  let s:markdown_syntax.link_format = g:zettel_link_format
  let s:vimwiki_syntax.link_format = g:zettel_link_format
endif

" source: https://stackoverflow.com/a/6271254/2467963
" get text of the visual selection
function! s:get_visual_selection() abort
  " Why is this not a built-in Vim script function?!
  let [line_start, column_start] = getpos("'<")[1:2]
  let [line_end, column_end] = getpos("'>")[1:2]
  let lines = getline(line_start, line_end)
  if len(lines) == 0
    return ''
  endif
  let lines[-1] = lines[-1][: column_end - (&selection == 'inclusive' ? 1 : 2)]
  let lines[0] = lines[0][column_start - 1:]
  return join(lines, "\n")
endfunction

" markdown test for front matter end
function! s:test_header_end_md(line, i) abort
  if a:i > 0 
    let l:pos = matchstrpos(a:line, "^\s*---")
    return l:pos[1]
  endif
  return -1
endfunction

" vimwiki test fot front matter end
function! s:test_header_end_wiki(line, i) abort
  " return false for all lines that start with % character
  let l:pos = matchstrpos(a:line,"^\s*%")
  if l:pos[1] > -1 
    return -1
  endif
  " first line which is not tag should be selected
  return 0
endfunction

" helper function to insert a text line to a new zettel
function! s:add_line(text) abort
  " don't append anything if the argument is empty string
  if len(a:text) > 0
    call append(line("1"), a:text)
  endif
endfunction

" enable functions to be passed as front_matter values
" this can be useful to dynamic value setting 
function! s:expand_front_matter_value(value) abort
  " enable execution of functions that expands to the correct value
  if type(a:value) == v:t_func
    return a:value()
  else
    return a:value
  endif
endfunction

function! s:make_header_item(key, value, header_format) abort
  let val = <sid>expand_front_matter_value(a:value)
  return printf(a:header_format, a:key, val)
endfunction

" add a variable to the zettel header
function! s:add_to_header(key, value, header_format) abort
  call <sid>add_line(s:make_header_item(a:key, a:value, a:header_format))
endfunction

let s:letters = "abcdefghijklmnopqrstuvwxyz"

" convert number to str (1 -> a, 27 -> aa)
function! s:numtoletter(num) abort
  let numletter = strlen(s:letters)
  let charindex = a:num % numletter
  let quotient = a:num / numletter
  if (charindex-1 == -1)
    let charindex = numletter
    let quotient = quotient - 1
  endif

  let result =  strpart(s:letters, charindex - 1, 1)
  if (quotient>=1)
    return <sid>numtoletter(float2nr(quotient)) . result
  endif 
  return result
endfunction

" copy of function from Vimwiki
" Params: full path to a wiki file and its wiki number
" Returns: a list of all links inside the wiki file
" Every list item has the form
" [target file, anchor, line number of the link in source file, column number]
function! s:get_links(wikifile, idx) abort
  if !filereadable(a:wikifile)
    return []
  endif

  let syntax = vimwiki#vars#get_wikilocal('syntax', a:idx)
  let rx_link = vimwiki#vars#get_syntaxlocal('wikilink', syntax)
  let links = []
  let lnum = 0

  for line in readfile(a:wikifile)
    let lnum += 1

    let link_count = 1
    while 1
      let col = match(line, rx_link, 0, link_count)+1
      let link_text = matchstr(line, rx_link, 0, link_count)
      echomsg("link text " . line . " - " . link_text)
      if link_text == ''
        break
      endif
      let link_count += 1
      let target = vimwiki#base#resolve_link(link_text, a:wikifile)
      if target.filename != '' && target.scheme =~# '\mwiki\d\+\|diary\|file\|local'
        call add(links, [target.filename, target.anchor, lnum, col])
      endif
    endwhile
  endfor

  return links
endfunction

" based on vimwiki
"   Loads tags metadata from file, returns a dictionary
function! s:load_tags_metadata() abort
  let metadata_path = vimwiki#tags#metadata_file_path()
  if !filereadable(metadata_path)
    return {}
  endif
  let metadata = {}
  for line in readfile(metadata_path)
    if line =~ s:tag_pattern
      continue
    endif
    let parts = matchlist(line, '^\(.\{-}\);"\(.*\)$')
    if parts[0] == '' || parts[1] == '' || parts[2] == ''
      throw 'VimwikiTags1: Metadata file corrupted'
    endif
    let std_fields = split(parts[1], '\t')
    if len(std_fields) != 3
      throw 'VimwikiTags2: Metadata file corrupted'
    endif
    let vw_part = parts[2]
    if vw_part[0] != "\t"
      throw 'VimwikiTags3: Metadata file corrupted'
    endif
    let vw_fields = split(vw_part[1:], "\t")
    if len(vw_fields) != 1 || vw_fields[0] !~ '^vimwiki:'
      throw 'VimwikiTags4: Metadata file corrupted'
    endif
    let vw_data = substitute(vw_fields[0], '^vimwiki:', '', '')
    let vw_data = substitute(vw_data, '\\n', "\n", 'g')
    let vw_data = substitute(vw_data, '\\r', "\r", 'g')
    let vw_data = substitute(vw_data, '\\t', "\t", 'g')
    let vw_data = substitute(vw_data, '\\\\', "\\", 'g')
    let vw_fields = split(vw_data, "\t")
    if len(vw_fields) != 2
      throw 'VimwikiTags5: Metadata file corrupted'
    endif
    let pagename = vw_fields[0]
    let entry = {}
    let entry.tagname  = std_fields[0]
    let entry.filename  = std_fields[1]
    let entry.lineno   = std_fields[2]
    let entry.link     = vw_fields[1]
    if has_key(metadata, pagename)
      call add(metadata[pagename], entry)
    else
      let metadata[pagename] = [entry]
    endif
  endfor
  return metadata
endfunction

" add link with title of the file referenced in the second argument to the
" array in the first argument
function! s:add_bulleted_link(lines, abs_filepath) abort
  let bullet = repeat(' ', vimwiki#lst#get_list_margin()) . vimwiki#lst#default_symbol().' '
  call add(a:lines, bullet.
        \ zettel#vimwiki#get_link(a:abs_filepath))
  return a:lines
endfunction

" insert list of links to the current page
function! s:insert_link_array(title, lines, level) abort
  let links_rx = '\m^\s*'.vimwiki#u#escape(vimwiki#lst#default_symbol()).' '
  call zettel#vimwiki#update_listing(a:lines, a:title, links_rx, a:level)
endfunction

" test if link in the Backlinks section
function! s:is_in_backlinks(file, filenamepattern) abort
  let f = readfile(a:file)
  let content = join(f, "\n")
  " search for backlinks section
  let backlinks_pattern = printf(s:section_pattern, g:zettel_backlinks_title)
  let backlinks_pos = matchstrpos(content, backlinks_pattern)
  " if we cannot find backlinks in the page return false
  if backlinks_pos[1] == -1 
    return -1
  endif
  let file_pos = matchstrpos(content, a:filenamepattern)
  " link is in backlinks when it is placed after the Backlinks section title
  return backlinks_pos[1] < file_pos[1]
endfunction

" find and return footer in the file
" footer is content below last horizontal rule (----)
function! s:read_footer(filename) abort
  let lines = readfile(a:filename)
  let footer_lines = []
  let found_footer = -1
  " return empty footer if we couldn't find the footer
  let footer = "" 
  " process lines from the last one and try to find the rule
  for line in reverse(lines) 
    if match(line, "^ \*----") == 0
      let found_footer = 0
      break
    endif
    call add(footer_lines, line)
  endfor
  if found_footer == 0
    let footer = join(reverse(footer_lines), "\n")
  endif
  return footer
endfunction

" check if the file with the current filename exits in wiki
function! s:wiki_file_not_exists(filename) abort
  let link_info = vimwiki#base#resolve_link(a:filename)
  return empty(glob(link_info.filename)) 
endfunction

" front_matter can be either list or dict. if it is a dict, then convert it to
" list
function! s:front_matter_list(front_matter) abort
  if type(a:front_matter) ==? v:t_list
    return a:front_matter
  endif
  " it is prefered to use a list for front_matter, as it keeps the order of
  " keys. but it is possible to use dict, to keep the backwards compatibility
  let newlist = []
  for key in keys(a:front_matter)
    call add(newlist, [key, a:front_matter[key]])
  endfor
  return newlist
endfunction

function! zettel#vimwiki#wiki_yank_name() abort
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
function! zettel#vimwiki#replace_file_with_link() abort
  let l:filename = expand('<cfile>')
  let l:link = zettel#vimwiki#get_link(l:filename)
  execute 'normal BvExa' . link
endfunction

" get user option for the current wiki
" it seems that it is not possible to set custom options in g:vimwiki_list
" so we need to use our own options
function! zettel#vimwiki#get_option(name, zettel_wiki_nr) abort
  if !exists('g:zettel_options')
    return ""
  end
  " the options for particular wikis must be in the same order as wiki
  " definitions in g:vimwiki_list
  let option_number = "g:zettel_options[" . a:zettel_wiki_nr . "]"
  if exists(option_number)
    if exists(option_number . "." . a:name)
      return g:zettel_options[a:zettel_wiki_nr][a:name]
    endif
  endif
  return ""
endfunction

function! zettel#vimwiki#update_listing(lines, title, links_rx, level) abort
  let generator = { 'data': a:lines }
  function generator.f() dict
        return self.data
  endfunction
  call vimwiki#base#update_listing_in_buffer(generator, a:title, a:links_rx, line('$')+1, a:level, 1)
endfunction

" Fixes for Neovim
if has('nvim')

" make string filled with random characters
function! zettel#vimwiki#make_random_chars() abort
  call luaeval("math.randomseed( os.time() )")
  let char_no = range(g:zettel_random_chars)
  let str_list = []
  for x in char_no
    call add(str_list, nr2char(luaeval("math.random(97,122)")))
  endfor
  return join(str_list, "")
endfunction

elseif v:version < 802
function! zettel#vimwiki#make_random_chars() abort
  let char_no = range(g:zettel_random_chars)
  let str_list = []
  for x in char_no
    call add(str_list, nr2char(matchstr(reltimestr(reltime()), '\v\.@<=\d+')%26+97))
  endfor
  return join(str_list, "")
endfunction

else

" make string filled with random characters
function! zettel#vimwiki#make_random_chars() abort
  let seed = srand()
  return range(g:zettel_random_chars)->map({-> (97+rand(seed) % 26)->nr2char()})->join('')
endfunction
endif

let s:randomchars = zettel#vimwiki#make_random_chars()

" find end of the front matter variables
function! zettel#vimwiki#find_header_end(filename) abort
  let lines = readfile(a:filename)
  " Markdown and Vimwiki use different formats for metadata header, select the
  " right one according to the file type
  let ext = fnamemodify(a:filename, ":e")
  let Header_test = function(ext ==? 'md' ? '<sid>test_header_end_md' : '<sid>test_header_end_wiki')
  let i = 0
  for line in lines
    let res = Header_test(line, i)
    if res > -1 
      return i
    endif
    let i = i + 1
  endfor
  return 0
endfunction

function! zettel#vimwiki#get_syntax_configuration(wiki_nr) abort
  if vimwiki#vars#get_wikilocal('syntax', a:wiki_nr) ==? 'markdown'
    return s:markdown_syntax
  else
    return s:vimwiki_syntax
  endif
endfunction

" title and date to a new zettel note
function! zettel#vimwiki#template(title, date, wiki_nr) abort
  let l:syntax = zettel#vimwiki#get_syntax_configuration(a:wiki_nr)
  if g:zettel_disable_front_matter == 0 
    call <sid>add_line(syntax.header_delimiter)
    let l:front_matter = zettel#vimwiki#get_option("front_matter", a:wiki_nr)
    if !empty(l:front_matter)
      let l:front_list = s:front_matter_list(l:front_matter)
      " we must reverse the list, because each line is inserted before the
      " ones inserted earlier
      for [l:key, l:value] in reverse(copy(l:front_list))
        " call append(l:last_header_line, <sid>make_header_item(l:values[0], l:values[1]))
        call s:add_to_header(l:key, l:value, l:syntax.header_format)
      endfor
    endif
    call <sid>add_to_header("date", a:date, l:syntax.header_format)
    call <sid>add_to_header("title", a:title, l:syntax.header_format)
    call <sid>add_line(syntax.header_delimiter)
  endif
endfunction


" sanitize title for filename
function! zettel#vimwiki#escape_filename(name) abort
  let name = substitute(a:name, "[%.%,%?%!%:]", "", "g") " remove unwanted characters
  let schar = vimwiki#vars#get_wikilocal('links_space_char') " ' ' by default
  let name = substitute(name, " ", schar, "g") " change spaces to link_space_char

  let name = tolower(name)
  return fnameescape(name)
endfunction

" count files that match pattern in the current wiki
function! zettel#vimwiki#count_files(pattern) abort
  let cwd = vimwiki#vars#get_wikilocal('path')
  let filelist = split(globpath(cwd, a:pattern), '\n')
  return len(filelist)
endfunction

function! zettel#vimwiki#next_counted_file() abort
  " count notes in the current wiki and return 
  let ext = vimwiki#vars#get_wikilocal('ext')
  let next_file = zettel#vimwiki#count_files("*" . ext) + 1
  return next_file
endfunction

function! zettel#vimwiki#new_zettel_name(title, wiki_nr) abort
  let l:newformat = g:zettel_format
  let l:filename = zettel#vimwiki#escape_filename(a:title)
  let l:raw_title = a:title 
  " expand title in the zettel_format
  let l:newformat = substitute(g:zettel_format, "%title", l:filename, "")
  let l:newformat = substitute(l:newformat, "%raw_title", l:raw_title, "")
  if matchstr(l:newformat, "%file_no") != ""
    " file_no counts files in the current wiki and adds 1
    let l:next_file = zettel#vimwiki#next_counted_file()
    let l:newformat = substitute(l:newformat, "%file_no", l:next_file, "")
  endif
  if matchstr(l:newformat, "%file_alpha") != ""
    " same as file_no, but convert numbers to letters
    let l:next_file = s:numtoletter(zettel#vimwiki#next_counted_file())
    let l:newformat = substitute(l:newformat,"%file_alpha", l:next_file, "")
  endif
  if matchstr(l:newformat, "%random") != ""
    " generate random characters, their number is set by g:zettel_random_chars
    " random characters are set using zettel#vimwiki#make_random_chars()
    " this function is set at the startup and then each time
    " zettel#vimwiki#create() is called. we don't call it here because we
    " would get wrong links in zettel_new_selected(). It calls new_zettel_name
    " twice.
    let l:newformat = substitute(l:newformat, "%random", s:randomchars, "")
  endif
  let l:final_format =  strftime(l:newformat)
  if !s:wiki_file_not_exists(l:final_format)
    " if the current file name is used, increase counter and add it as a
    " letter to the file name. this ensures that we don't reuse the filename
    let l:file_count = zettel#vimwiki#count_files(l:final_format . "*")
    let l:final_format = l:final_format . s:numtoletter(l:file_count)
  endif
  let g:zettel_current_id = l:final_format
  let l:final_format = vimwiki#vars#get_wikilocal('path', a:wiki_nr) . l:final_format . vimwiki#vars#get_wikilocal('ext', a:wiki_nr)
  return l:final_format
endfunction

" the optional argument is the wiki number
function! zettel#vimwiki#save_wiki_page(format, ...) abort
  let defaultidx = vimwiki#vars#get_bufferlocal('wiki_nr')
  let idx = get(a:, 1, defaultidx)
  let newfile = vimwiki#vars#get_wikilocal('path', idx) . a:format . vimwiki#vars#get_wikilocal('ext',idx )
  " copy the captured file to a new zettel
  execute "w! " . newfile
  return newfile
endfunction

" find title in the zettel file and return correct link to it
function! zettel#vimwiki#get_link(filename) abort
  let title =zettel#vimwiki#get_title(a:filename)
  let wikiname = fnamemodify(a:filename, ":t:r")
  if title == ""
    " use the Zettel filename as title if it is empty
    let title = wikiname
  endif
  let link= zettel#vimwiki#format_link(wikiname, title)
  return link
endfunction

" return list of files that match a pattern
function! zettel#vimwiki#wikigrep(pattern) abort
  let paths = []
  let idx = vimwiki#vars#get_bufferlocal('wiki_nr')
  let path = fnameescape(vimwiki#vars#get_wikilocal('path', idx))
  let ext = vimwiki#vars#get_wikilocal('ext', idx)
  try
    let command = 'vimgrep ' . a:pattern . 'j ' . path . "*" . ext
    noautocmd  execute  command
  catch /^Vim\%((\a\+)\)\=:E480/   " No Match
    "Ignore it, and move on to the next file
  endtry
  for d in getqflist()
    let filename = fnamemodify(bufname(d.bufnr), ":p")
    call add(paths, filename)
  endfor
  call uniq(paths)
  return paths
endfunction

function! zettel#vimwiki#format_file_title(format, file, title) abort
  let link = substitute(a:format, "%title", a:title, "")
  let link = substitute(link, "%link", a:file, "")
  return link
endfunction

" use different link style for wiki and markdown syntaxes
function! zettel#vimwiki#format_link(file, title) abort
  return zettel#vimwiki#format_file_title(s:link_format, a:file, a:title)
endfunction

function! zettel#vimwiki#format_search_link(file, title) abort
  return zettel#vimwiki#format_file_title(s:link_format, a:file, a:title)
endfunction

" This function is executed when the page referenced by the inserted link
" doesn't contain  title. The cursor is placed at the position where title 
" should start, and insert mode is started
function! zettel#vimwiki#insert_mode_in_title() abort
  execute "normal! " .s:insert_mode_title_format | :startinsert
endfunction

function! zettel#vimwiki#get_title(filename) abort
  let filename = a:filename
  let title = ""
  let lsource = readfile(filename)
  " this code comes from vimwiki's html export plugin
  for line in lsource 
    if line =~# '^\s*%\=title'
      let title = matchstr(line, '^\s*%\=title:\=\s\zs.*')
      return title
    endif
  endfor 
  return ""
endfunction

" create new zettel note
" there is one optional argument, the zettel title
function! zettel#vimwiki#create(title, wiki_nr) abort
  " name of the new note
  let l:filename = zettel#vimwiki#new_zettel_name(a:title, a:wiki_nr)
  let l:date_format = g:zettel_date_format
  let l:date = strftime(l:date_format)
  " update random chars used in %random name format 
  let s:randomchars = zettel#vimwiki#make_random_chars()
  let s:zettel_date = date " save zettel date
  " detect if the wiki file exists
  let l:wiki_not_exists = s:wiki_file_not_exists(l:filename)
  execute ':edit ' . l:filename
  " add basic template to the new file
  if l:wiki_not_exists
    call zettel#vimwiki#template(a:title, l:date, a:wiki_nr)
    return l:filename
  endif
  return -1
endfunction

function! zettel#vimwiki#vimwiki_nr(zettel_wiki_nr) abort
  let l:zettel_wikis_count = len(g:zettel_wikis_nr)
  if a:zettel_wiki_nr > l:zettel_wikis_count
    return vimwiki#vars#get_bufferlocal('wiki_nr')
  endif
  let l:vimwiki_nr = get(g:zettel_wikis_nr, a:zettel_wiki_nr, -1)
  return l:vimwiki_nr
endfunction

function! zettel#vimwiki#zettel_new(title, zettel_wiki_nr) abort
  let l:title = a:title
  if l:title ==# ''
    let l:title = input('New note title: ')
  endif
  let l:vimwiki_nr = zettel#vimwiki#vimwiki_nr(a:zettel_wiki_nr)
  let l:filename = zettel#vimwiki#create(l:title, l:vimwiki_nr)
  if l:filename == -1
    return 0
  endif

  " insert the template text from a template file if it is configured in
  " g:zettel_options for the current wiki
  let l:template = zettel#vimwiki#get_option("template", a:zettel_wiki_nr)
  if !empty(l:template)
    let l:variables = get(a:, 2, 0)
    if empty(l:variables)
      " save file, in order to prevent errors in variable reading
      execute "w"
      let l:variables = zettel#vimwiki#prepare_template_variables(expand("%"), a:1)
      " backlink contains link to the new note itself, so we will just disable
      " it. backlinks are available only when the new note is created using
      " ZettelNewSelectedMap (`z` letter in visual mode by default).
      let l:variables.backlink = ""
    endif
    " we may reuse varaibles from the parent zettel. date would be wrong in this case,
    " so we will overwrite it with the current zettel date
    let l:variables.date = s:zettel_date 
    call zettel#vimwiki#expand_template(l:template, l:variables)
  endif
endfunction

" crate zettel link from a selected text
function! zettel#vimwiki#zettel_new_selected() abort
  let title = <sid>get_visual_selection()
  let name = zettel#vimwiki#new_zettel_name(title)
  " prepare_template_variables needs the file saved on disk
  execute "w"
  " make variables that will be available in the new page template
  let variables = zettel#vimwiki#prepare_template_variables(expand("%"), title)
  " replace the visually selected text with a link to the new zettel
  " \\%V.*\\%V. should select the whole visual selection
  execute "normal! :'<,'>s/\\%V.*\\%V./" . zettel#vimwiki#format_link( name, "\\\\0") ."\<cr>\<C-o>"
  call zettel#vimwiki#zettel_new(title, variables)
endfunction

" prepare variables that will be available to expand in the new note template
function! zettel#vimwiki#prepare_template_variables(filename, title) abort
  let variables = {}
  let variables.title = a:title
  let variables.date = s:zettel_date
  " add variables from front_matter, to make them available in the template
  let front_matter = zettel#vimwiki#get_option("front_matter")
  if !empty(front_matter)
    let front_list = s:front_matter_list(front_matter)
    for entry in copy(front_list)
      let variables[entry[0]] = <sid>expand_front_matter_value(entry[1])
    endfor
  endif
  let variables.backlink = zettel#vimwiki#get_link(a:filename)
  " we want to save footer of the parent note. It can contain stuff that can
  " be useful in the child note, like citations,  etc. Footer is everything
  " below last horizontal rule (----)
  let variables.footer = s:read_footer(a:filename)
  return variables
endfunction

" populate new note using template
function! zettel#vimwiki#expand_template(template, variables) abort
  " readfile returns list, we need to convert it to string 
  " in order to do global replace
  let template_file = expand(a:template)
  if !filereadable(template_file) 
    return 
  endif
  let content = readfile(template_file)
  let text = join(content, "\n")
  for key in keys(a:variables)
    let text = substitute(text, "%" . key, a:variables[key], "g")
  endfor
  " when front_matter is disabled, there is an empty line before 
  " start of the inserted template. we need to ignore it.
  let correction = 0
  if line('$') == 1 
    let correction = 1
  endif
  " add template at the end
  " we must split it, 
  for xline in split(text, "\n")
    call append(line('$') - correction, xline)
  endfor
endfunction

" make new zettel from a file. the file contents will be copied to a new
" zettel, the original file contents will be replaced with the zettel filename
" use temporary file if you want to keep the original file
function! zettel#vimwiki#zettel_capture(wnum,...) abort
  let origfile = expand("%")
  execute "set ft=vimwiki"
  " This probably doesn't work with current vimwiki code
  if a:wnum > vimwiki#vars#number_of_wikis()
    echomsg 'Vimwiki Error: Wiki '.a:wnum.' is not registered in g:vimwiki_list!'
    return
  endif
  if a:wnum > 0
    let idx = a:wnum
  else
    let idx = 0
  endif
  let title = zettel#vimwiki#get_title(origfile)
  let format = zettel#vimwiki#new_zettel_name(title)
  " let link_info = vimwiki#base#resolve_link(format)
  let newfile = zettel#vimwiki#save_wiki_page(format, idx)
  " delete contents of the captured file
  execute "normal! ggdG"
  " replace it with a address of the zettel file
  execute "normal! i" . newfile 
  execute "w"
  " open the new zettel
  execute "e " . newfile
endfunction

" based on vimwikis "get wiki links", not stripping file extension
function! zettel#vimwiki#get_wikilinks(wiki_nr, also_absolute_links) abort
  let files = vimwiki#base#find_files(a:wiki_nr, 0)
  if a:wiki_nr == vimwiki#vars#get_bufferlocal('wiki_nr')
    let cwd = vimwiki#path#wikify_path(expand('%:p:h'))
  elseif a:wiki_nr < 0
    let cwd = vimwiki#vars#get_wikilocal('path') . vimwiki#vars#get_wikilocal('diary_rel_path')
  else
    let cwd = vimwiki#vars#get_wikilocal('path', a:wiki_nr)
  endif
  let result = []
  for wikifile in files
    let wikifile = vimwiki#path#relpath(cwd, wikifile)
    call add(result, wikifile)
  endfor
  if a:also_absolute_links
    for wikifile in files
      if a:wiki_nr == vimwiki#vars#get_bufferlocal('wiki_nr')
        let cwd = vimwiki#vars#get_wikilocal('path')
      elseif a:wiki_nr < 0
        let cwd = vimwiki#vars#get_wikilocal('path') . vimwiki#vars#get_wikilocal('diary_rel_path')
      endif
      let wikifile = '/'.vimwiki#path#relpath(cwd, wikifile)
      call add(result, wikifile)
    endfor
  endif
  return result
endfunction

" based on vimwikis "generate links", adding the %title to the link
function! zettel#vimwiki#generate_links() abort
  let lines = []

  let links = zettel#vimwiki#get_wikilinks(vimwiki#vars#get_bufferlocal('wiki_nr'), 0)
  call reverse(sort(links))

  let bullet = repeat(' ', vimwiki#lst#get_list_margin()) . vimwiki#lst#default_symbol().' '
  for link in links
    let abs_filepath = vimwiki#path#abs_path_of_link(link)
    "let abs_filepath = link
    "if !s:is_diary_file(abs_filepath)
      call add(lines, bullet.
            \ zettel#vimwiki#get_link(abs_filepath))
    "endif
  endfor
  call s:insert_link_array(g:zettel_generated_index_title, lines, g:zettel_generated_index_title_level)
endfunction

" based on vimwikis "backlinks"
" insert backlinks of the current page in a section
function! zettel#vimwiki#backlinks() abort
  let current_filename = expand("%:t:r")
  " find [filename| or [filename] to support both wiki and md syntax
  let filenamepattern = printf(s:grep_link_pattern, current_filename)
  let locations = []
  let backfiles = zettel#vimwiki#wikigrep(filenamepattern)
  for file in backfiles
    " only add backlink if it is not already backlink
    let is_backlink = s:is_in_backlinks(file, current_filename)
    if is_backlink < 1
      " Make sure we don't add ourselves
      if !(file ==# expand("%:p"))
        call s:add_bulleted_link(locations, file)
      endif
    endif
  endfor

  if empty(locations)
    echomsg 'Vimzettel: No other file links to this file'
  else
    call uniq(locations)
    " Insert back links section
    call s:insert_link_array(g:zettel_backlinks_title, locations, g:zettel_backlinks_title_level)
  endif
endfunction

function! zettel#vimwiki#inbox() abort
  call vimwiki#base#check_links()
  let linklist = getqflist()
  cclose
  let paths = []
  " normalize the current wiki path
  let cwd = fnamemodify(vimwiki#vars#get_wikilocal('path'), ":p:h")
  let bullet = repeat(' ', vimwiki#lst#get_list_margin()) . vimwiki#lst#default_symbol().' '
  for d in linklist
    " detect files that are not reachable from the wiki index
    let filenamematch = matchstr(d.text,'\zs.*\ze is not reachable')
    if filenamematch != "" && filereadable(filenamematch)
      " use only files from the current wiki, we get files from all registered
      " wikis here
      let filepath = fnamemodify(filenamematch, ":p:h")
      if filepath ==# cwd
        call add(paths, bullet.
              \ zettel#vimwiki#get_link(filenamematch))
      endif
    endif
  endfor
  if empty(paths)
  else
    " remove duplicates and insert inbox section
    call uniq(paths)
    call s:insert_link_array(g:zettel_unlinked_notes_title, paths, g:zettel_unlinked_notes_title_level)
  endif

endfunction

" based on vimwiki
function! zettel#vimwiki#generate_tags(...) abort
  let need_all_tags = (a:0 == 0)
  let specific_tags = a:000

  let metadata = s:load_tags_metadata()

  " make a dictionary { tag_name: [tag_links, ...] }
  let tags_entries = {}
  for entries in values(metadata)
    for entry in entries
      if has_key(tags_entries, entry.tagname)
        call add(tags_entries[entry.tagname], entry.filename)
      else
        let tags_entries[entry.tagname] = [entry.filename]
      endif
    endfor
  endfor

  let rxH_TemplateName = 'rxH'.(g:zettel_generated_index_title_level + 1).'_Template'
  let lines = []
  let bullet = repeat(' ', vimwiki#lst#get_list_margin()).vimwiki#lst#default_symbol().' '
  for tagname in sort(keys(tags_entries))
    if need_all_tags || index(specific_tags, tagname) != -1
      call extend(lines, [
            \ '',
            \ substitute(vimwiki#vars#get_syntaxlocal(rxH_TemplateName), '__Header__', tagname, ''),
            \ '' ])
      for taglink in reverse(sort(tags_entries[tagname]))
        let filepath = vimwiki#path#abs_path_of_link(taglink)
        if filereadable(filepath)
          call add(lines, bullet . zettel#vimwiki#get_link(filepath))
        endif
      endfor
    endif
  endfor

  let links_rx = '\m\%(^\s*$\)\|\%('.vimwiki#vars#get_syntaxlocal('rxH2').'\)\|\%(^\s*'
        \ .vimwiki#u#escape(vimwiki#lst#default_symbol()).' '
        \ .vimwiki#vars#get_syntaxlocal('rxWikiLink').'$\)'

  call zettel#vimwiki#update_listing(lines, g:zettel_generated_tags_title, links_rx, g:zettel_generated_tags_title_level)
endfunction

