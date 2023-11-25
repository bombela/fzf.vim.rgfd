let s:cpo_save = &cpo
set cpo&vim

let s:bin_dir = expand('<sfile>:p:h:h:h:h').'/bin/'
let s:bin = {
\ 'fd':      s:bin_dir.'fd.sh',
\ 'rg':      s:bin_dir.'rg.sh',}

" From the FZF plugin (not fzf.vim).
" ============================================================================
let s:is_win = has('win32') || has('win64')
if s:is_win
  function! s:fzf_call(fn, ...)
    let shellslash = &shellslash
    try
      set noshellslash
      return call(a:fn, a:000)
    finally
      let &shellslash = shellslash
    endtry
  endfunction
else
  function! s:fzf_call(fn, ...)
    return call(a:fn, a:000)
  endfunction
endif

function! s:fzf_expand(fmt)
  return s:fzf_call('expand', a:fmt, 1)
endfunction

function! s:fzf_fnamemodify(fname, mods)
  return s:fzf_call('fnamemodify', a:fname, a:mods)
endfunction

function! s:escape(path)
  let path = fnameescape(a:path)
  return s:is_win ? escape(path, '$') : path
endfunction

function! s:open(cmd, target)
  if stridx('edit', a:cmd) == 0 && s:fzf_fnamemodify(a:target, ':p') ==# s:fzf_expand('%:p')
    return
  endif
  execute a:cmd s:escape(a:target)
endfunction

let s:default_action = {
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-x': 'split',
  \ 'ctrl-v': 'vsplit' }

function! s:common_sink(action, lines) abort
  if len(a:lines) < 2
    return
  endif
  let key = remove(a:lines, 0)
  let Cmd = get(a:action, key, 'e')
  if type(Cmd) == type(function('call'))
    return Cmd(a:lines)
  endif
  if len(a:lines) > 1
    augroup fzf_swap
      autocmd SwapExists * let v:swapchoice='o'
            \| call s:warn('fzf: E325: swap file exists: '.s:fzf_expand('<afile>'))
    augroup END
  endif
  try
    let empty = empty(s:fzf_expand('%')) && line('$') == 1 && empty(getline(1)) && !&modified
    " Preserve the current working directory in case it's changed during
    " the execution (e.g. `set autochdir` or `autocmd BufEnter * lcd ...`)
    let cwd = exists('w:fzf_pushd') ? w:fzf_pushd.dir : expand('%:p:h')
    for item in a:lines
      if item[0] != '~' && item !~ (s:is_win ? '^[A-Z]:\' : '^/')
        let sep = s:is_win ? '\' : '/'
        let item = join([cwd, item], cwd[len(cwd)-1] == sep ? '' : sep)
      endif
      if empty
        execute 'e' s:escape(item)
        let empty = 0
      else
        call s:open(Cmd, item)
      endif
      if !has('patch-8.0.0177') && !has('nvim-0.2') && exists('#BufEnter')
            \ && isdirectory(item)
        doautocmd BufEnter
      endif
    endfor
  catch /^Vim:Interrupt$/
  finally
    silent! autocmd! fzf_swap
  endtry
endfunction
" ============================================================================

function s:sinkall(basedir, lines)
    let basedir = fnamemodify(a:basedir, ':p')
    let lines = extend(a:lines[0:0], map(a:lines[1:], {_, line -> basedir.line}))
	let action = get(g:, 'fzf_action', s:default_action)
	return s:common_sink(action, lines)
endfunction

let s:fdcfg = tempname()
function! fzf#vim#rgfd#fd(bang, pattern='.', path='', resume=0)
  let p = 'fd'
  let pz = 'fdz'
  let cfg = s:fdcfg
  let qfd = cfg.'.fd' " store fd pattern
  let qfzf = cfg.'.fzf' " store fzf pattern
  let bdir =getcwd()
  let dir = expand(a:path)
  let absdir = fnamemodify(dir, ':p')
  if a:resume == 1
    let dirh = split(system("sha1sum", absdir))[0]
  else
    let dirh = ''
  endif
  let sh = printf('%s %s %s %s %s ', shellescape(s:bin.fd), shellescape(cfg),
        \ shellescape(bdir), shellescape(dir), shellescape(dirh))
  if a:pattern == '.'
    let pattern = ''
  else
    let pattern = shellescape(a:pattern)
  endif
  let initial_cmd = sh.'run '.shellescape(pattern)
  if a:resume == 1
    let initial_cmd = initial_cmd.' 1'
  endif
  let reload_cmd = sh.'run {q}'
  let reload_repeat_cmd = sh.'repeat'

  let P = {msg -> 'transform-prompt('.sh.'prompt '.msg.')'}
  let C = {cmd -> 'execute-silent('.sh.cmd.')+'.P('').'+reload('.reload_repeat_cmd.')'}
  let T = {t -> 'execute-silent('.sh.'toggle '.t.')+'.P('').'+reload('.reload_repeat_cmd.')'}

  let hl_color = 'red'
  let spec = {'options': ['--query', '', '--ansi', '--scheme=path',
        \'--bind', 'start:unbind(change,alt-z)+'.P(pz),
        \'--prompt', pz.'> ',
        \'--bind', 'change:reload:sleep 0.01; '.reload_cmd,
        \'--bind', 'alt-x:unbind(alt-x)+'.P(p).'+disable-search+transform-query(echo {q} > '.qfzf.'; cat '.qfd.')+rebind(change,alt-z)',
        \'--bind', 'alt-z:unbind(change,alt-z)+'.P(pz).'+enable-search+transform-query(echo {q} > '.qfd.'; cat '.qfzf.')+rebind(alt-x)',
        \'--bind', 'alt-h:'.T('h'),
        \'--bind', 'alt-i:'.T('i'),
        \'--bind', 'alt-l:'.T('l'),
        \'--bind', 'alt-d:'.T('d'),
        \'--bind', 'alt-r:'.C('dir {}'),
        \'--bind', 'ctrl-r:'.C('dir'),
        \'--bind', 'alt-u:'.C('up'),
        \'--header-lines', '1',
        \'--color=dark,hl:'.hl_color.':bold,hl+:'.hl_color.':reverse',
        \], 'source': initial_cmd}
  let spec = fzf#vim#with_preview(spec)
  " TODO use full prefix path
  "return fzf#vim#files('', spec, a:bang)
  let spec.sh = sh
  function! spec.newsink(lines)
    let basedir = get(systemlist(self.sh.'prefix'), 0, '')
    return s:sinkall(basedir, a:lines)
  endfunction
  let spec['sink*'] = remove(spec, 'newsink')
  return fzf#vim#files('', spec, a:bang)
endfunction

" ----------------------------------------------------------------------------
let &cpo = s:cpo_save
unlet s:cpo_save
