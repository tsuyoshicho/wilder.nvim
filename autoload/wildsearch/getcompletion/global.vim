function! wildsearch#getcompletion#global#do(ctx) abort
  if a:ctx.pos < len(a:ctx.cmdline)
    let l:delimiter = a:ctx.cmdline[a:ctx.pos]

    let a:ctx.pos += 1
  endif

  let l:arg_start = a:ctx.pos
  let l:delimiter_reached = 0

  while a:ctx.pos < len(a:ctx.cmdline)
    if a:ctx.cmdline[a:ctx.pos] ==# '\' &&
          \ a:ctx.pos + 1 < len(a:ctx.cmdline)
      let a:ctx.pos += 1
    elseif a:ctx.cmdline[a:ctx.pos] ==# l:delimiter
      let l:delimiter_reached = 1

      break
    endif

    let a:ctx.pos += 1
  endwhile

  " delimiter not reached
  if !wildsearch#getcompletion#skip_regex#do(a:ctx, l:delimiter)
    let a:ctx.pos = l:arg_start
    return
  endif

  " skip delimiter
  let a:ctx.pos += 1

  " new command
  let a:ctx.cmd = ''

  call wildsearch#getcompletion#main#do(a:ctx)
endfunction