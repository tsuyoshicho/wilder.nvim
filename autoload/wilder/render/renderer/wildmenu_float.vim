function! wilder#render#renderer#wildmenu_float#make(args) abort
  let l:state = wilder#render#renderer#wildmenu#prepare_state(a:args)
  let l:state.ns_id = nvim_create_namespace('')
  let l:state.buf = -1
  let l:state.win = -1
  let l:state.cmdheight = -1

  return {
        \ 'render': {ctx, result -> s:render(l:state, ctx, result)},
        \ 'pre_hook': {ctx -> s:pre_hook(l:state, ctx)},
        \ 'post_hook': {ctx -> s:post_hook(l:state, ctx)},
        \ }
endfunction

function! s:render(state, ctx, result) abort
  if a:state.win == -1
    return
  endif

  let l:chunks = wilder#render#renderer#wildmenu#make_hl_chunks(
        \ a:state, &columns, a:ctx, a:result)

  let l:in_sandbox = 0
  try
    call nvim_buf_set_lines(a:state.buf, 0, -1, v:true, [])
  catch /E523/
    " might be in sandbox due to expr mapping
    let l:in_sandbox = 1
  endtry

  if l:in_sandbox
    let l:state = copy(a:state)
    call timer_start(0, {-> s:render_chunks(l:state, l:chunks)})
  else
    call s:render_chunks(a:state, l:chunks)
  endif
endfunction

function! s:render_chunks(state, chunks) abort
  if a:state.win == -1
    return
  endif

  let a:state.columns = &columns

  let l:cmdheight = s:get_cmdheight()
  if a:state.cmdheight != l:cmdheight
    let l:offset = l:cmdheight != 1 && stridx(&display, 'msgsep') >= 0 ? 2 : 1
    call nvim_win_set_config(a:state.win, {
          \ 'relative': 'editor',
          \ 'row': &lines - s:get_cmdheight() - l:offset,
          \ 'col': 0,
          \ })
    let a:state.cmdheight = l:cmdheight
  endif

  let l:text = ''
  for l:elem in a:chunks
    let l:text .= l:elem[0]
  endfor

  call nvim_buf_set_lines(a:state.buf, 0, -1, v:true, [l:text])
  call nvim_buf_clear_namespace(a:state.buf, a:state.ns_id, 0, -1)

  let l:start = 0
  for l:elem in a:chunks
    let l:end = l:start + len(l:elem[0])

    let l:hl = get(l:elem, 1, a:state.highlights['default'])
    call nvim_buf_add_highlight(a:state.buf, a:state.ns_id, l:hl, 0, l:start, l:end)

    let l:start = l:end
  endfor

  redraw
endfunction

function! s:pre_hook(state, ctx) abort
  if a:state.buf == -1
    let a:state.buf = nvim_create_buf(v:false, v:true)
  endif

  if a:state.win == -1
    let a:state.cmdheight = &cmdheight
    let a:state.win = wilder#render#renderer#open_win(
          \ a:state.buf, &lines - s:get_cmdheight() - 1,
          \ 0, 1, &columns)
  endif

  call wilder#render#renderer#wildmenu#component_pre_hook(a:state.left, a:ctx)
  call wilder#render#renderer#wildmenu#component_pre_hook(a:state.right, a:ctx)
endfunction

function! s:post_hook(state, ctx) abort
  if a:state.buf != -1
    call nvim_buf_clear_namespace(a:state.buf, a:state.ns_id, 0, -1)
  endif

  if a:state.win != -1
    let l:win = a:state.win
    let a:state.win = -1
    " cannot call nvim_win_close() while cmdline-window is open
    if getcmdwintype() ==# ''
      call nvim_win_close(l:win, 1)
    else
      execute 'autocmd CmdWinLeave * ++once call timer_start(0, {-> nvim_win_close(' . l:win . ', 0)})'
    endif
  endif

  call wilder#render#renderer#wildmenu#component_post_hook(a:state.left, a:ctx)
  call wilder#render#renderer#wildmenu#component_post_hook(a:state.right, a:ctx)
endfunction

function! s:get_cmdheight() abort
  let l:cmdheight = &cmdheight
  let l:columns = &columns
  let l:cmdline = getcmdline()

  " include the cmdline character
  let l:display_width = strdisplaywidth(l:cmdline) + 1
  let l:actual_height = l:display_width / l:columns
  if l:display_width % l:columns != 0
    let l:actual_height += 1
  endif

  if l:cmdheight > l:actual_height
    return l:cmdheight
  endif

  return l:actual_height
endfunction
