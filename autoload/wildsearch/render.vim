function! wildsearch#render#make_page(ctx, candidates)
  if empty(a:candidates)
    return [-1, -1]
  endif

  let l:index = a:ctx.index
  let l:space = a:ctx.space
  let l:page = a:ctx.page
  let l:separator = a:ctx.separator

  if l:page != [-1, -1] && l:index >= l:page[0] && l:index <= l:page[1]
    return l:page
  endif

  let l:start = l:index
  let l:end = l:start

  let l:width = strdisplaywidth(a:candidates[l:index])
  let l:space = l:space - l:width
  let l:separator_width = strdisplaywidth(l:separator)

  while l:end + 1 < len(a:candidates) &&
        \ l:space > strdisplaywidth(a:candidates[l:end + 1]) + l:separator_width
    let l:space -= strdisplaywidth(a:candidates[l:end + 1]) + l:separator_width

    let l:end += 1
  endwhile

  return [l:start, l:end]
endfunction

function! wildsearch#render#draw(ctx, candidates)
  let l:res = ''

  let l:res .= wildsearch#render#draw_components(s:left, a:ctx, a:candidates)
  let l:res .= wildsearch#render#draw_candidates(a:ctx, a:candidates)
  let l:res .= wildsearch#render#draw_components(s:right, a:ctx, a:candidates)

  return l:res
endfunction

function! wildsearch#render#draw_candidates(ctx, candidates)
  let l:selected = a:ctx.selected
  let l:space = a:ctx.space
  let l:page = a:ctx.page
  let l:separator = a:ctx.separator

  if l:page == [-1, -1]
    return repeat('.', l:space)
  endif

  let l:start = l:page[0]
  let l:end = l:page[1]
  let g:_wildsearch_candidates = map(copy(a:candidates[l:start : l:end+1]), {_, x -> strtrans(x)})

  let l:current = l:start
  let l:res = '%#StatusLine#'
  let l:len = 0

  while l:current <= l:end
    if l:current != l:start
      let l:res .= l:separator
      let l:len += strdisplaywidth(l:separator)
    endif

    if l:current == l:selected
      let l:res .= '%#WildMenu#%{g:_wildsearch_candidates[' . string(l:current-l:start) . ']}%#StatusLine#'
    else
      let l:res .= '%{g:_wildsearch_candidates[' . string(l:current-l:start) . ']}'
    endif

    let l:len += strdisplaywidth(a:candidates[l:current-l:start])
    let l:current += 1
  endwhile

  return l:res . repeat('.', l:space - l:len)
endfunction

function! wildsearch#render#draw_components(components, ctx, candidates)
  let l:res = ''

  for l:component in a:components
    if type(l:component) == v:t_string
      let l:res .= '%#StatusLine#'
      let l:res .= l:component
      continue
    endif

    let l:res .= '%#' . get(l:component, 'hl', 'StatusLine') . '#'

    if type(l:component.f) == v:t_func
      let l:res .= l:component.f(a:ctx, a:candidates)
    else
      let l:res .= l:component.f
    endif
  endfor

  return l:res
endfunction

function! wildsearch#render#space_used(ctx, candidates)
  if !exists('s:left') && !exists('s:right')
    call wildsearch#render#set_components(wildsearch#render#default())
  endif

  let l:len = 0

  let l:components = s:left + s:right
  for l:component in l:components
    if type(l:component) == v:t_string
      let l:len += strdisplaywidth(l:component)
    elseif has_key(l:component, 'len')
      if type(l:component.len) == v:t_func
        let l:len += l:component.len(a:ctx, a:candidates)
      else
        let l:len += l:component.len
      endif
    else
      if type(l:component.f) == v:t_func
        let l:res = l:component.f(a:ctx, a:candidates)
      else
        let l:res = l:component.f
      endif

      let l:len += strdisplaywidth(l:res)
    endif
  endfor

  return l:len
endfunction

function! wildsearch#render#set_components(args)
  let s:left = a:args.left
  let s:right = a:args.right
endfunction

let s:hl_index = 0
let s:hl_map = {}

function! wildsearch#render#exe_hl()
  for l:hl_name in keys(s:hl_map)
    exe s:hl_map[l:hl_name]
  endfor
endfunction

function! wildsearch#render#make_hl(args)
  let l:ctermfg = a:args[0][0]
  let l:ctermbg = a:args[0][1]
  let l:guifg = a:args[1][0]
  let l:guibg = a:args[1][1]

  let l:hl_name = 'Wildsearch_' . s:hl_index
  let s:hl_index += 1

  let l:cmd = 'hi ' . l:hl_name . ' '

  if len(a:args[0]) > 2
    let l:cmd .= 'cterm=' . a:args[0][2] . ' '
  endif

  let l:cmd .= 'ctermfg=' . l:ctermfg . ' '
  let l:cmd .= 'ctermbg=' . l:ctermbg . ' '

  if len(a:args[1]) > 2
    let l:cmd .= 'gui=' . a:args[1][2] . ' '
  endif

  let l:cmd .= 'guifg=' . l:guifg . ' '
  let l:cmd .= 'guibg=' . l:guibg

  exe l:cmd

  let s:hl_map[l:hl_name] = l:cmd
  return l:hl_name
endfunction

function! wildsearch#render#get_background_colors(group, ) abort
  redir => l:highlight
  silent execute 'silent highlight ' . a:group
  redir END

  let l:link_matches = matchlist(l:highlight, 'links to \(\S\+\)')
  if len(l:link_matches) > 0 " follow the link
    return wildsearch#render#get_background_colors(l:link_matches[1])
  endif

  if !empty(matchlist(l:highlight, 'cterm=\S\*reverse\S\*'))
    let l:ctermbg = wildsearch#render#match_highlight(l:highlight, 'ctermfg=\([0-9A-Za-z]\+\)')
  else
    let l:ctermbg = wildsearch#render#match_highlight(l:highlight, 'ctermbg=\([0-9A-Za-z]\+\)')
  endif

  if !empty(matchlist(l:highlight, 'gui=\S*reverse\S*'))
    let l:guibg = wildsearch#render#match_highlight(l:highlight, 'guifg=\([#0-9A-Za-z]\+\)')
  else
    let l:guibg = wildsearch#render#match_highlight(l:highlight, 'guibg=\([#0-9A-Za-z]\+\)')
  endif

  return [l:ctermbg, l:guibg]
endfunction

function! wildsearch#render#match_highlight(highlight, pattern) abort
  let l:matches = matchlist(a:highlight, a:pattern)
  if len(l:matches) == 0
    return 'NONE'
  endif
  return l:matches[1]
endfunction

function! wildsearch#render#default()
  let l:search_hl = wildsearch#render#make_hl([[0, 0], ['#fdf6e3', '#b58900', 'bold']])
  return {
        \ 'left': [wildsearch#string(' SEARCH ', l:search_hl), wildsearch#separator('', l:search_hl, 'StatusLine'), ' '],
        \ 'right': [' ', wildsearch#index(), ' '],
        \ }
endfunction
