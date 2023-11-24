let s:cpo_save = &cpo
set cpo&vim

let s:bin_dir = expand('<sfile>:p:h:h:h:h').'/bin/'
let s:bin = {
\ 'fd':      s:bin_dir.'fd.sh',
\ 'rg':      s:bin_dir.'rg.sh',}

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
  return fzf#vim#files('', spec, a:bang)
  let spec.sh = sh
  function! spec.newsink(lines)
    let basedir = get(systemlist(self.sh.'basedir'), 0, '')
    let basedir = fnamemodify(basedir, ':p')
    echom("basedir:".basedir)
    let lines = a:lines
    let lines = extend(a:lines[0:0], map(a:lines[1:], {_, line -> basedir.line}))
    for line in lines
      echom("line:".line)
    endfor
    return lines
  endfunction
  let spec['sink*'] = remove(spec, 'newsink')
endfunction
" ------------------------------------------------------------------
let &cpo = s:cpo_save
unlet s:cpo_save
