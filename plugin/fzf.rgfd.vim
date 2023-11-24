if exists('g:loaded_fzf_vim_rgfd')
  finish
endif
let g:loaded_fzf_vim_rgfd = 1

let s:cpo_save = &cpo
set cpo&vim

command! -bang -nargs=* -complete=dir Fd call fzf#vim#rgfd#fd(<bang>0, <f-args>)

let &cpo = s:cpo_save
unlet s:cpo_save
