function! s:escape(path)
  return escape(a:path, ' $%#''"\')
endfunction


"============================== User settings ==============================

if !exists('g:nv_directory')
  echomsg 'g:nv_directory is not defined'
  finish
endif

let s:ext = get(g:, 'nv_default_extension', '.md')
let s:wrap_text = get(g:, 'nv_wrap_preview_text', 0) ? 'wrap' : ''

" Show preview unless user set it to be hidden
let s:show_preview = get(g:, 'nv_show_preview', 1) ? '' : 'hidden'

" How wide to make preview window. 72 characters is default because pandoc
" does hard wraps at 72 characters.
let s:preview_width = exists('g:nv_preview_width') ? string(float2nr(str2float(g:nv_preview_width) / 100.0 * &columns)) : ''


" Valid options are ['up', 'down', 'right', 'left']. Default is 'right'. No colon for
" this command since it's first in the list.
let s:preview_direction = get(g:,'nv_preview_direction', 'right')


" Expand NV Directory and add trailing slash to avoid issues later.
let s:main_dir = expand(g:nv_directory) "get(g:, 'nv_main_directory', s:dirs[0])

"=========================== Keymap ========================================

" TODO add var to allow users to define split, vsplit, or tabedit
let s:create_note_key = get(g:, 'nv_create_note_key', 'ctrl-x')
let s:create_note_window = get(g:, 'nv_create_note_window', 'tabedit ')

let s:keymap = get(g:, 'nv_keymap',
            \ {'ctrl-s': 'split ',
            \ 'ctrl-v': 'vertical split ',
            \ 'ctrl-t': 'tabedit ',
            \ })

" Use `extend` in case user overrides default keys
let s:keymap = extend(s:keymap, {
            \ s:create_note_key : s:create_note_window,
            \ })

" FZF expect comma sep str
let s:expect_keys = join(keys(s:keymap) + get(g:, 'nv_expect_keys', []), ',')

"============================ Ignore patterns ==============================

function! s:surround_in_single_quotes(str)
    return "'" . a:str . "'"
endfunction

function! s:ignore_list_to_str(pattern)
    return join(map(copy(a:pattern), ' " --ignore " . s:surround_in_single_quotes(v:val) . " " ' ))
endfunction


let s:nv_ignore_pattern = exists('g:nv_ignore_pattern') ? s:ignore_list_to_str(g:nv_ignore_pattern) : ''


"============================== Other settings ===========================
let s:highlight_format = has('termguicolors') ? 'truecolor' : 'xterm256'

"============================== Handler Function ===========================

function! s:handler(lines) abort
    " exit if empty
    if a:lines == [] || a:lines == ['','','']
        return
    endif
   " Expect at least 2 elements, `query` and `keypress`, which may be empty
   " strings.
   let query    = a:lines[0]
   let keypress = a:lines[1]
   " `edit` is fallback in case something goes wrong
   let cmd = get(s:keymap, keypress, 'edit ')
   " Preprocess candidates here. expect lines to have fmt
   " filename:linenum:content

   " Handle creating note.
   if keypress ==? s:create_note_key
     let candidates = [s:escape(s:main_dir  . '/' . query . s:ext)]
   else
       let filenames = a:lines[2:]
       let candidates = []
       for filename in filenames
           " don't forget traiiling space in replacement
           let name = substitute(filename, '\v(.{-}):\d+$', '\1', '')
           call add(candidates, s:escape(s:main_dir . '/' . name))
       endfor
   endif

   for candidate in candidates
       execute cmd . ' ' . candidate
   endfor

endfunction


" If the file you're looking for is empty, then why does it even exist? It's a
" note. Just type its name. Hence we ignore lines with only space characters,
" and use the "\S" regex.

" Use a big ugly option list. The '.. ' is because fzf wants a term of the
" form 'N.. ' where N is a number.

" Use backslash in front of 'ag' to ignore aliases.

command! -nargs=* -bang NV
  \ call fzf#run(
    \ fzf#wrap({
      \ 'sink*': function(exists('*NV_note_handler') ? 'NV_note_handler' : '<sid>handler'),
      \ 'source': '\ag ' .
        \ s:nv_ignore_pattern  .
        \ '-l ' . 
        \ '"' . (<q-args> ==? '' ? '\S' : <q-args>) .
        \ '"' . ' 2>/dev/null ' .
        \ s:escape(s:main_dir) . ' ' .
        \ '2>/dev/null ' ,
      \ 'options': '--print-query --ansi --multi --exact ' .
        \ '--delimiter="/" --with-nth=-1 ' .
        \ '--tiebreak=length,begin,index ' .
        \ '--expect=' . s:expect_keys . ' ' .
        \ '--bind alt-a:select-all,alt-d:deselect-all,alt-p:toggle-preview,alt-u:page-up,alt-d:page-down,ctrl-w:backward-kill-word ' .
        \ '--color hl:68,hl+:110 ' .
        \ '--preview="(highlight --quiet --force --out-format=' . s:highlight_format . ' --style solarized-dark -l {} || coderay {} || cat {}) 2> /dev/null | head -' . &lines . '" ' .
        \ '--preview-window=' . join([s:preview_direction , s:preview_width ,  s:wrap_text ,  s:show_preview]) . ' ' ,
    \ })
  \ )
