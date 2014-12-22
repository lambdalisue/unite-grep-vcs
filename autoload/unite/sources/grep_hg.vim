"******************************************************************************
" A Unite source for call 'hg grep'
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

function! unite#sources#grep_hg#define() "{{{
  return s:source
endfunction "}}}

function! unite#sources#grep_hg#is_available() "{{{
  if !executable('hg')
    return 0
  endif
  call unite#util#system('hg root')
  return (unite#util#get_last_status() == 0) ? 1 : 0
endfunction "}}}

" Inherit from 'grep' source
let s:origin = unite#sources#grep#define()
let s:source = deepcopy(s:origin)
let s:source['name'] = 'grep/hg'
let s:source['description'] = 'candidates from hg grep'

function! s:source.hooks.on_init(args, context) "{{{
  if !unite#sources#grep_hg#is_available()
    call unite#print_source_error(
          \ 'The directory is not in marcurial repository.',
          \ s:source.name)
    return
  endif
  return s:origin.hooks.on_init(a:args, a:context)
endfunction " }}}


function! s:source.gather_candidates(args, context) "{{{
  "
  " Note:
  "   Most of code in this function was copied from unite.vim
  "
  if !executable('hg')
    call unite#print_source_message(
          \ 'command "hg" is not executable.', s:source.name)
    let a:context.is_async = 0
    return []
  endif

  if !unite#util#has_vimproc()
    call unite#print_source_message(
          \ 'vimproc plugin is not installed.', self.name)
    let a:context.is_async = 0
    return []
  endif

  if empty(a:context.source__target)
        \ || a:context.source__input == ''
    call unite#print_source_message('Canceled.', s:source.name)
    let a:context.is_async = 0
    return []
  endif

  if a:context.is_redraw
    let a:context.is_async = 1
  endif

  if a:context.source__target == ['/']
    " Do not specify source target
    let cmdline = printf('hg grep -n %s %s',
      \   a:context.source__extra_opts,
      \   string(a:context.source__input),
      \)
  else
    let cmdline = printf('hg grep -n %s %s %s',
      \   a:context.source__extra_opts,
      \   string(a:context.source__input),
      \   join(map(a:context.source__target,
      \           "substitute(v:val, '/$', '', '')")),
      \)
  endif

  call unite#print_source_message('Command-line: ' . cmdline, s:source.name)

  " Note:
  "   'hg grep' does not have color thus $TERM='dumb' is not required.
  let a:context.source__proc = vimproc#plineopen3(
        \ vimproc#util#iconv(cmdline, &encoding, 'char'), 1)

  return self.async_gather_candidates(a:args, a:context)
endfunction "}}}

function! s:source.async_gather_candidates(args, context) "{{{
  "
  " Note:
  "   Most of code in this function was copied from unite.vim
  "
  if !has_key(a:context, 'source__proc')
    let a:context.is_async = 0
    return []
  endif

  let stderr = a:context.source__proc.stderr
  if !stderr.eof
    " Print error.
    let errors = filter(unite#util#read_lines(stderr, 100),
          \ "v:val !~ '^\\s*$'")
    if !empty(errors)
      call unite#print_source_error(errors, s:source.name)
    endif
  endif

  let stdout = a:context.source__proc.stdout
  if stdout.eof
    " Disable async.
    let a:context.is_async = 0
    call a:context.source__proc.waitpid()
  endif

  let candidates = map(unite#util#read_lines(stdout, 1000),
          \ "unite#util#iconv(v:val, g:unite_source_grep_encoding, &encoding)")
  let candidates = map(filter(candidates,
        \  'v:val =~ "^.\\+:.\\+$"'),
        \ '[v:val, split(v:val[2:], ":", 1)]')

  let _ = []
  for candidate in candidates
    let dict = {
          \   'action__path' : candidate[0][:1].candidate[1][0],
          \   'action__line' : candidate[1][2],
          \   'action__text' : join(candidate[1][3:], ':'),
          \ }

    let dict.action__path =
          \ unite#util#substitute_path_separator(
          \   fnamemodify(dict.action__path, ':p'))

    let dict.word = printf('%s:%s:%s',
          \  unite#util#substitute_path_separator(
          \     fnamemodify(dict.action__path, ':.')),
          \ dict.action__line, dict.action__text)

    call add(_, dict)
  endfor

  return _
endfunction "}}}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
