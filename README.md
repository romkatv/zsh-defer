# zsh-defer: Deferred execution of zsh commands

`zsh-defer` defers execution of a zsh command until zsh has nothing else to do and is waiting for
user input. Its intended purpose is staged zsh startup. It works similarly to *Turbo mode* in
[zinit](https://github.com/zdharma-continuum/zinit).

Features:

- **Small and clean**: The API consists of a single function implemented in ~150 lines of
  straightforward zsh.
- **Fast to load**: It takes under 1ms to source `zsh-defer.plugin.zsh`.
- **Easy to use**: `source slow.zsh` => `zsh-defer source slow.zsh`.
- **Plugin manager agnostic**: Can be used with any plugin manager or even without one.

## Table of Contents

1. [Installation](#installation)
1. [Usage](#usage)
1. [Example](#example)
1. [Caveats](#caveats)
1. [FAQ](#faq)
   1. [Is it possible to autoload zsh-defer?](#is-it-possible-to-autoload-zsh-defer)
   1. [Is it possible to find out from within a command whether it's being executed by zsh-defer?](#is-it-possible-to-find-out-from-within-a-command-whether-its-being-executed-by-zsh-defer)
   1. [Is zsh-defer a plugin manager?](#is-zsh-defer-a-plugin-manager)
   1. [How useful is it?](#how-useful-is-it)
   1. [Is zsh-defer compatible with Instant Prompt in Powerlevel10k?](#is-zsh-defer-compatible-with-instant-prompt-in-powerlevel10k)
   1. [Can I use zsh-defer together with zinit?](#can-i-use-zsh-defer-together-with-zinit)
   1. [How does zsh-defer compare to Turbo mode in zinit?](#how-does-zsh-defer-compare-to-turbo-mode-in-zinit)
   1. [Why so many references to and comparisons with zinit?](#why-so-many-references-to-and-comparisons-with-zinit)

## Installation

1. Clone the repo.
```zsh
git clone https://github.com/romkatv/zsh-defer.git ~/zsh-defer
```
2. Add the following line at the top of `~/.zshrc`:
```zsh
source ~/zsh-defer/zsh-defer.plugin.zsh
```

*Using a plugin manager? You can install zsh-defer the same way as any other zsh plugin hosted on
GitHub.*

## Usage

```text
zsh-defer [{+|-}12dmshpr] [-t delay] word...
zsh-defer [{+|-}12dmshpr] [-t delay] -c list
```

Queues up the specified command for deferred execution. Whenever zle is idle, the next command is
popped from the queue. If the command has been queued up with `-t delay`, execution of the command
and all deferred commands after it is delayed by the specified number of seconds (non-negative real
number) without blocking zle. Duration can be specified in any format accepted by `sleep(1)`. After
that the command is executed either as `word...` with every word quoted, or, if `-c` is specified,
as `eval list`. Commands are executed in the same order they are queued up.

Options can be used to enable (`+x`) or disable (`-x`) extra actions taken during and after the
execution of the command. By default, all actions are enabled. The same option can be enabled or
disabled more than once -- the last instance wins.

| **Option** | **Action**                                                                                                    |
| ---------- |---------------------------------------------------------------------------------------------------------------|
| *1*        | Redirect standard output to `/dev/null`.                                                                      |
| *2*        | Redirect standard error to `/dev/null`.                                                                       |
| *d*        | Call `chpwd` hooks.                                                                                           |
| *m*        | Call `precmd` hooks.                                                                                          |
| *s*        | Invalidate suggestions from [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions).          |
| *z*        | Invalidate highlighting from [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting). |
| *p*        | Call `zle reset-prompt`.                                                                                      |
| *r*        | Call `zle -R`.                                                                                                |
| *a*        | Shorthand for all options: *12dmszpr*.                                                                        |

## Example

Here's an example of `~/.zshrc` that uses `zsh-defer` to achieve staged zsh startup. When starting
zsh, it takes only a few milliseconds for this `~/.zshrc` to be evaluated and for prompt to appear.
After that, prompt and the command line buffer are refreshed and buffered keyboard input are
processed after the execution of every deferred command.

```zsh
source ~/zsh-defer/zsh-defer.plugin.zsh

PS1="%F{12}%~%f "
RPS1="%F{240}loading%f"
setopt promp_subst

zsh-defer source ~/zsh-autosuggestions/zsh-autosuggestions.zsh
zsh-defer source ~/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
zsh-defer source ~/.nvm/nvm.sh
zsh-defer -c 'RPS1="%F{2}\$(git rev-parse --abbrev-ref HEAD 2>/dev/null)%f"'
```

Zsh startup without `zsh-defer`. Prompt appears once everything is loaded.

![zsh startup without zsh-defer](https://raw.githubusercontent.com/romkatv/zsh-defer/master/docs/zsh-startup-without-defer.gif)

Zsh startup with `zsh-defer`. Prompt appears instantly and gets updated after every startup stage.

![zsh startup with zsh-defer](https://raw.githubusercontent.com/romkatv/zsh-defer/master/docs/zsh-startup-with-defer.gif)

1. zsh-autosuggestions is loaded: completion suggestion appears.
2. zsh-highlighting is loaded: `nvm` in the command line turns red (no such command).
3. nvm is loaded: `nvm` turns green (recognized command).
4. `RPS1` is set: the name of the current Git branch appears.

## Caveats

`zsh-defer` executes commands from zle. This has several ramifications.

- Commands cannot read standard input. Thus, commands that may require keyboard input should not be
  deferred.
- Output from commands can be invisible and can cause prompt to be reprinted. This is the reason
  why `zsh-defer` redirects standard output and standard error to `/dev/null` by default. This
  behavior can be disabled with `+1` and `+2`.
- Some plugins don't expect to be sourced from zle and may fail to properly initialize.
  - Corollary: It's often necessary to rely on implementation details of plugins in order to load
    them from zle. This exposes the user to much higher risk of breakage when updating plugins.
    The default options in `zsh-defer` can help you sidestep these issues in many cases but not
    always.

`zsh-defer` executes commands in function scope with `LOCAL_OPTIONS`, `LOCAL_PATTERNS` and
`LOCAL_TRAPS` options. This can break initialization scripts that use `typeset` without explicit
`-g`, set options, change patterns or install traps.

## FAQ

### Is it possible to autoload zsh-defer?

Yes.

Instead of this:

```zsh
source ~/zsh-defer/zsh-defer.plugin.zsh
```

You can do this:

```zsh
autoload -Uz ~/zsh-defer/zsh-defer
```

### Is it possible to find out from within a command whether it's being executed by zsh-defer?

Yes. Check whether `zsh_defer_options` parameter is set.

```zsh
function say-hi() {
  if (( $+zsh_defer_options )); then
    echo "Hello from zsh-defer with options: $zsh_defer_options" >>/tmp/log
  else
    echo "Hello from without zsh-defer" >>/tmp/log
  fi
}

say-hi            # Hello from without zsh-defer
zsh-defer say-hi  # Hello from zsh-defer with options: 12dmshp
```

### Is zsh-defer a plugin manager?

No. `zsh-defer` is a function that allows you to defer execution of zsh commands. You can use it
on its own or with a plugin manager.

### How useful is it?

[About as useful](https://github.com/romkatv/zsh-bench#deferred-initialization) as Turbo mode in
zinit.

### Is zsh-defer compatible with Instant Prompt in Powerlevel10k?

Yes. Although if you are using [Powerlevel10k](https://github.com/romkatv/powerlevel10k/) with
[Instant Prompt](https://github.com/romkatv/zsh-bench#instant-prompt) you almost certainly don't
need to use deferred loading of any kind.

### Can I use zsh-defer together with zinit?

Yes, both ways.

You can load `zsh-defer` with zinit the same way as any other plugin.

```zsh
zinit light romkatv/zsh-defer
```

You can defer a `zinit` command with `zsh-defer` the same way as any other command.

```zsh
zsh-defer zinit light zsh-users/zsh-autosuggestions
zsh-defer zinit light zsh-users/zsh-syntax-highlighting
```

### How does zsh-defer compare to Turbo mode in zinit?

They are quite similar. Both allow you to defer execution of a zsh command and both execute the
command from zle, with all the [negative consequences](#caveats) that this entails.

`zsh-defer` is most useful to those who don't use zinit as it gives them access to Turbo mode that
they otherwise didn't have. However, there are also a few minor benefits to using
`zsh-defer zinit light` compared to the builtin Turbo mode:

- `zsh-defer` guarantees that all buffered keyboard input gets processed before every deferred
  command.
- The argument of `-t` can be fractional.
- The default options of `zsh-defer` are fairly effective at mitigating the
  [negative side effects](#caveats) of deferred loading.
- Options provide full flexibility that hardcore zsh users might desire.
- `zsh-defer` has a short and easy-to-understand implementation.

*Has zinit closed the gap on one or more of these points? Please send a PR removing them from the
list.*

On the other hand, `zinit ice wait` has its own advantages:

- *I don't know any. Please help expanding this section.*

### Why so many references to and comparisons with zinit?

Turbo mode in zinit is the only other robust implementation of deferred zsh command execution that
I'm aware of. There is also `zsh/sched` but it's underpowered by comparison.

Note that `zsh-defer` is not a plugin manager and thus not an alternative to zinit.
