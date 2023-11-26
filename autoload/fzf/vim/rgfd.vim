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

" From fzf.vim
" ============================================================================
let s:TYPE = {'bool': type(0), 'dict': type({}), 'funcref': type(function('call')), 'string': type(''), 'list': type([])}

function! s:conf(name, default)
  let conf = get(g:, 'fzf_vim', {})
  return get(conf, a:name, get(g:, 'fzf_' . a:name, a:default))
endfunction

function! s:execute_silent(cmd)
  silent keepjumps keepalt execute a:cmd
endfunction

" [key, [filename, [stay_on_edit: 0]]]
function! s:action_for(key, ...)
  let Cmd = get(get(g:, 'fzf_action', s:default_action), a:key, '')
  let cmd = type(Cmd) == s:TYPE.string ? Cmd : ''

  " See If the command is the default action that opens the selected file in
  " the current window. i.e. :edit
  let edit = stridx('edit', cmd) == 0 " empty, e, ed, ..

  " If no extra argument is given, we just execute the command and ignore
  " errors. e.g. E471: Argument required: tab drop
  if !a:0
    if !edit
      normal! m'
      silent! call s:execute_silent(cmd)
    endif
  else
    " For the default edit action, we don't execute the action if the
    " selected file is already opened in the current window, or we are
    " instructed to stay on the current buffer.
    let stay = edit && (a:0 > 1 && a:2 || fnamemodify(a:1, ':p') ==# expand('%:p'))
    if !stay
      normal! m'
      call s:execute_silent((len(cmd) ? cmd : 'edit').' '.s:escape(a:1))
    endif
  endif
endfunction

function! s:fill_quickfix(name, list)
  if len(a:list) > 1
	let Handler = s:conf('listproc_'.a:name, s:conf('listproc', function('fzf#vim#listproc#quickfix')))
    call call(Handler, [a:list], {})
    return 1
  endif
  return 0
endfunction

function! s:ag_to_qf(line)
  let parts = matchlist(a:line, '\(.\{-}\)\s*:\s*\(\d\+\)\%(\s*:\s*\(\d\+\)\)\?\%(\s*:\(.*\)\)\?')
  let dict = {'filename': &acd ? fnamemodify(parts[1], ':p') : parts[1], 'lnum': parts[2], 'text': parts[4]}
  if len(parts[3])
    let dict.col = parts[3]
  endif
  return dict
endfunction

function! s:ag_handler(name, lines)
  if len(a:lines) < 2
    return
  endif

  let list = map(filter(a:lines[1:], 'len(v:val)'), 's:ag_to_qf(v:val)')
  if empty(list)
    return
  endif

  call s:action_for(a:lines[0], list[0].filename, len(list) > 1)
  if s:fill_quickfix(a:name, list)
    return
  endif

  " Single item selected
  let first = list[0]
  try
    execute first.lnum
    if has_key(first, 'col')
      call cursor(0, first.col)
    endif
    normal! zvzz
  catch
  endtry
endfunction
" ============================================================================

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
    let pattern = a:pattern
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
  let spec.sh = sh
  function! spec.newsink(lines)
    let basedir = get(systemlist(self.sh.'prefix'), 0, '')
    let basedir = fnamemodify(basedir, ':p')
    let lines = extend(a:lines[0:0], map(a:lines[1:], {_, line -> basedir.line}))
	let action = get(g:, 'fzf_action', s:default_action)
	return s:common_sink(action, lines)
  endfunction
  let spec['sink*'] = remove(spec, 'newsink')
  return fzf#vim#files('', spec, a:bang)
endfunction

let s:rgcfg = tempname()
function! fzf#vim#rgfd#rg(bang, pattern, path='', resume=0)
  let p = 'rg'
  let pz = 'rgz'
  let cfg = s:rgcfg
  let qrg = cfg.'.rg' " store rg pattern
  let qfzf = cfg.'.fzf' " store fzf pattern
  let bdir =getcwd()
  let dir = expand(a:path)
  let absdir = fnamemodify(dir, ':p')
  if a:resume == 1
    let dirh = split(system("sha1sum", absdir))[0]
  else
    let dirh = ''
  endif
  let sh = printf('%s %s %s %s %s ', shellescape(s:bin.rg), shellescape(cfg),
        \ shellescape(bdir), shellescape(dir), shellescape(dirh))
  if a:pattern == '.'
    let pattern = ''
  else
    let pattern = a:pattern
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
        \'--bind', 'alt-x:unbind(alt-x)+'.P(p).'+disable-search+transform-query(echo {q} > '.qfzf.'; cat '.qrg.')+rebind(change,alt-z)',
        \'--bind', 'alt-z:unbind(change,alt-z)+'.P(pz).'+enable-search+transform-query(echo {q} > '.qrg.'; cat '.qfzf.')+rebind(alt-x)',
        \'--bind', 'alt-h:'.T('h'),
        \'--bind', 'alt-i:'.T('i'),
		\'--bind', 'alt-b:'.T('b'),
        \'--bind', 'alt-l:'.T('l'),
        \'--bind', 'alt-r:'.C('dir {}'),
        \'--bind', 'ctrl-r:'.C('dir'),
        \'--bind', 'alt-u:'.C('up'),
        \'--header-lines', '1',
        \'--color=dark,hl:'.hl_color.':bold,hl+:'.hl_color.':reverse',
        \], 'source': initial_cmd}
  let spec = fzf#vim#with_preview(spec)
  let spec.sh = sh
  function! spec.newsink(lines)
    let basedir = get(systemlist(self.sh.'prefix'), 0, '')
    let basedir = fnamemodify(basedir, ':p')
    let lines = extend(a:lines[0:0], map(a:lines[1:], {_, line -> basedir.line}))
	let action = get(g:, 'fzf_action', s:default_action)
	return s:ag_handler('rg', lines)
  endfunction
  let spec['sink*'] = remove(spec, 'newsink')
  return fzf#vim#grep(initial_cmd, 1, spec, a:bang)
endfunction

" ----------------------------------------------------------------------------
let &cpo = s:cpo_save
unlet s:cpo_save
