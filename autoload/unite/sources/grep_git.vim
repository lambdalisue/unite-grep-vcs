"******************************************************************************
" A Unite source for call 'git grep'
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

function! unite#sources#grep_git#define() "{{{
  return s:source
endfunction "}}}

function! unite#sources#grep_git#is_available() "{{{
  if !executable('git')
    return 0
  endif
  call unite#util#system('git rev-parse')
  return (unite#util#get_last_status() == 0) ? 1 : 0
endfunction "}}}
function! unite#sources#grep_git#repository_root() "{{{
  if !executable('git')
    return ''
  endif
  let stdout = unite#util#system('git rev-parse --show-toplevel')
  return (unite#util#get_last_status() == 0) ? stdout : ''
endfunction "}}}

" Inherit from 'grep' source
let s:origin = unite#sources#grep#define()
let s:source = deepcopy(s:origin)
let s:source['name'] = 'grep/git'
let s:source['description'] = 'candidates from git grep'

function! s:source.hooks.on_init(args, context) "{{{
  if !unite#sources#grep_git#is_available()
    call unite#print_source_error(
          \ 'The directory is not in git repository.',
          \ s:source.name)
    return
  endif
  if get(a:args, 0, '') ==# '/'
    " the behaviour of 'Unite grep' has changed from aa6afa9.
    let a:args[0] = unite#sources#grep_git#repository_root()
  endif
  return s:origin.hooks.on_init(a:args, a:context)
endfunction " }}}


function! s:source.gather_candidates(args, context) "{{{
  "
  " Note:
  "   Most of code in this function was copied from unite.vim
  "
  if !executable('git')
    call unite#print_source_message(
          \ 'command "git" is not executable.', s:source.name)
    let a:context.is_async = 0
    return []
  endif

  if !unite#util#has_vimproc()
    call unite#print_source_message(
          \ 'vimproc plugin is not installed.', self.name)
    let a:context.is_async = 0
    return []
  endif

  if empty(a:context.source__targets)
        \ || a:context.source__input == ''
    call unite#print_source_message('Canceled.', s:source.name)
    let a:context.is_async = 0
    return []
  endif

  if a:context.is_redraw
    let a:context.is_async = 1
  endif

  let cmdline = printf('git grep -n --no-color %s %s -- %s',
    \   a:context.source__extra_opts,
    \   string(a:context.source__input),
    \   unite#helper#join_targets(a:context.source__targets),
    \)
  call unite#print_source_message('Command-line: ' . cmdline, s:source.name)

  " Note:
  "   --no-color is specified thus $TERM='dumb' is not required (actually git
  "   will blame if the $TERM value is not properly configured thus it should
  "   not be 'dumb').
  " 
  " Note:
  "   'git grep' does not work properly with PTY
  "
  let a:context.source__proc = vimproc#plineopen3(
        \ vimproc#util#iconv(cmdline, &encoding, 'char'), 0)

  return self.async_gather_candidates(a:args, a:context)
endfunction "}}}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
