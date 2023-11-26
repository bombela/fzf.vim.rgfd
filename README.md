fzf vim - rg/fd support
===============

Interactive search through files with `rg` and searching
files with `fd` with [fzf.vim][fzf.vim].

Installation
------------

fzf.vim.rgfd depends on [fzf.vim][fzf.vim] which depends on the basic Vim
plugin of [the main fzf repository][fzf-main], which means you need to **set up
"fzf", "fzf.vim", and "fzf.vim.rgfd on Vim**. To learn more about fzf/Vim integration, see
[README-VIM][README-VIM].

[fzf.vim]: https://github.com/junegunn/fzf.vim
[fzf-main]: https://github.com/junegunn/fzf
[README-VIM]: https://github.com/junegunn/fzf/blob/master/README-VIM.md

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'bombela/fzf.vim.rgfd'
```

`fzf#install()` makes sure that you have the latest binary, but it's optional,
so you can omit it if you use a plugin manager that doesn't support hooks.

Commands
--------

| `:Rg [PATTERN]`        | [rg][rg] search result
| `:Fd [PATTERN]`        | [fd][fd] search result

Configuration example
---------------------

```viml
" Current working directory file search (project search).
" The search resumes with the last searched path. ctrl-r resets to the CWD.
map <C-p> :Fd . . 1<CR>
" Relative to current file search (relative search).
" The search never resumes.
map <C-\> :Fd . %:h 0<CR>

" Current working directory, grep word under cursor (project search).
" The search resumes with the last searched path. ctrl-r resets to the CWD.
map <A-p> :execute "Rg ".expand("<cword>")<CR>
" Relative to current file, grep word under cursor (relative search).
" The search never resumes.
map <A-\> :execute "Rg ".expand("<cword>")." %:h"<CR>
```

License
-------

MIT

[rg]:    https://github.com/BurntSushi/ripgrep
[fd]:    https://github.com/sharkdp/fd
