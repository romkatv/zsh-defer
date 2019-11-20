# zsh-defer: Defer execution of a command until zle is idle.
#
# There are two way to load function zsh-defer:
#
# 1. Eager loading:
#
#   source ~/zsh-defer/zsh-defer.plugin.zsh
#
# 2. Lazy loading:
#
#   fpath+=(~/zsh-defer)
#   autoload -Uz zsh-defer
#
# Once zsh-defer is loaded, type `zsh-defer -h` for usage.

'builtin' 'local' '-a' '_zsh_defer_opts'
[[ ! -o 'aliases'         ]] || _zsh_defer_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || _zsh_defer_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || _zsh_defer_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

typeset -ga _defer_tasks

function zsh-defer-reset-autosuggestions_() {
  unsetopt warn_nested_var
  orig_buffer=
  orig_postdisplay=
}
zle -N zsh-defer-reset-autosuggestions_

function _zsh-defer-schedule() {
  local fd
  if [[ $1 == *[1-9]* ]]; then
    exec {fd}< <(sleep $1)
  else
    exec {fd}</dev/null
  fi
  zle -F $fd _zsh-defer-resume
}

function _zsh-defer-resume() {
  emulate -L zsh
  zle -F $1
  exec {1}>&-
  while (( $#_defer_tasks && !KEYS_QUEUED_COUNT && !PENDING )); do
    local delay=${_defer_tasks[1]%% *}
    local task=${_defer_tasks[1]#* }
    if [[ $delay == *[1-9]* ]]; then
      _zsh-defer-schedule $delay
      _defer_tasks[1]="0 $task"
      return 0
    else
      _zsh-defer-apply $task
      shift _defer_tasks
    fi
  done
  (( $#_defer_tasks )) && _zsh-defer-schedule
  return 0
}
zle -N _zsh-defer-resume

function _zsh-defer-apply() {
  local opts=${1%% *}
  local cmd=${1#* }
  local dir=${(%):-%/}
  local -i fd1=-1 fd2=-1
  [[ $opts == *1* ]] && exec {fd1}>&1 1>/dev/null
  [[ $opts == *2* ]] && exec {fd2}>&2 2>/dev/null
  {
    local zsh_defer_options=$opts  # this is a part of public API
    () {
      if [[ $opts == *c* ]]; then
        eval $cmd
      else
        "${(@Q)${(z)cmd}}"
      fi
    }
    emulate -L zsh
    local hook hooks
    [[ $opts == *d* && ${(%):-%/} != $dir ]] && hooks+=($chpwd  $chpwd_functions)
    [[ $opts == *m*                       ]] && hooks+=($precmd $precmd_functions)
    for hook in $hooks; do
      (( $+functions[$hook] )) || continue
      $hook
      emulate -L zsh
    done
    [[ $opts == *s* && $+ZSH_AUTOSUGGEST_STRATEGY    == 1 ]] && zle zsh-defer-reset-autosuggestions_
    [[ $opts == *h* && $+_ZSH_HIGHLIGHT_PRIOR_BUFFER == 1 ]] && _ZSH_HIGHLIGHT_PRIOR_BUFFER=
    [[ $opts == *p* ]] && zle reset-prompt
    [[ $opts == *r* ]] && zle -R
  } always {
    (( fd1 >= 0 )) && exec 1>&$fd1 {fd1}>&-
    (( fd2 >= 0 )) && exec 2>&$fd2 {fd2}>&-
  }
}

function zsh-defer() {
  emulate -L zsh -o extended_glob
  local all=12dmshpr
  local opts=$all cmd opt OPTIND OPTARG delay=0
  while getopts ":hc:t:a$all" opt; do
    case $opt in
      *h)
        print -r -- 'zsh-defer [{+|-}'$all'] [-t seconds] -c command
zsh-defer [{+|-}'$all'] [-t seconds] [command [args]...]

Defer execution of the command until zle is idle. Typically called form ~/.zshrc.
Deferred commands run in the same order they are queued up. 

  -c command  Run `eval command` instead of `command args...`.
  -t seconds  Delay execution of deferred commands by this many seconds.
  -1          Don'\''t redirect stdout to /dev/null.
  -2          Don'\''t redirect stderr to /dev/null.
  -d          Don'\''t call chpwd hooks.
  -m          Don'\''t call precmd hooks.
  -s          Don'\''t invalidate suggestions from zsh-autosuggestions.
  -h          Don'\''t invalidate highlighting from zsh-syntax-highlighting.
  -p          Don'\''t call `zle reset-prompt`.
  -r          Don'\''t call `zle -R`.
  -a          The same as -12dmshpra.

Example ~/.zshrc:

  source ~/zsh-defer/zsh-defer.plugin.zsh

  PROMPT="%F{12}%~%f "
  RPROMPT="%F{240}loading%f"
  setopt prompt_subst

  zsh-defer source ~/zsh-autosuggestions/zsh-autosuggestions.zsh
  zsh-defer source ~/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  zsh-defer source ~/.nvm/nvm.sh
  zsh-defer -c '\''RPROMPT="%F{2}\$(git rev-parse --abbrev-ref HEAD 2>/dev/null)%f"'\''
  zsh-defer -a zle -M "zsh: initialization complete"

Full documentation at: <https://github.com/romkatv/zsh-defer>.'
        return 0
      ;;
      c)
        if [[ $opts == *c* ]]; then
          print -r -- "zsh-defer: duplicate option: -c" >&2
          return 1
        fi
        opts+=c
        cmd=$OPTARG
      ;;
      t)
        if [[ $OPTARG == *' '* ]]; then
          print -r -- "zsh-defer: invalid -t argument: $OPTARG" >&2
          return 1
        fi
        delay=$OPTARG
      ;;
      +c|+t) print -r -- "zsh-defer: invalid option: $opt" >&2;               return 1;;
      \?)    print -r -- "zsh-defer: invalid option: $OPTARG" >&2;            return 1;;
      :)     print -r -- "zsh-defer: missing required argument: $OPTARG" >&2; return 1;;
      a)  [[ $opts == *c* ]] && opts=c     || opts=;;
      +a) [[ $opts == *c* ]] && opts=c$all || opts=$all;;
      +?) [[ $opts == *${opt:1}* ]] || opts+=${opt:1};;
      ?)  [[ $opts == (#b)(*)$opt(*) ]] && opts=$match[1]$match[2];;
    esac
  done
  if [[ $opts != *c* ]]; then
    cmd="${(@q)@[OPTIND,-1]}"
  elif (( OPTIND <= ARGC )); then
    print -r -- "zsh-defer: unexpected positional argument: ${*[OPTIND]}" >&2
    return 1
  fi
  (( $#_defer_tasks )) || _zsh-defer-schedule
  _defer_tasks+="$delay $opts $cmd"
}

(( ${#_zsh_defer_opts} )) && setopt ${_zsh_defer_opts[@]}
'builtin' 'unset' '_zsh_defer_opts'
