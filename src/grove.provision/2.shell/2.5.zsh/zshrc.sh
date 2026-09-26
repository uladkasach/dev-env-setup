# enable profiling if ZPROF=1 (usage: shelltest.profile)
[[ "${ZPROF:-}" == "1" ]] && zmodload zsh/zprof

# history
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt hist_ignore_dups       # skip consecutive duplicates
setopt hist_reduce_blanks     # trim whitespace

# shell options
setopt auto_cd                # type dir name to cd
setopt interactive_comments   # allow # comments in interactive shell

# word chars: what counts as part of a "word" for Ctrl+W, Ctrl+Left/Right, etc
# default includes -, /, _ — remove them so delete stops at path segments
WORDCHARS=''

# key bindings
bindkey '^[[H'  beginning-of-line                 # Home
bindkey '^[[F'  end-of-line                       # End
bindkey '^[[3~' delete-char                       # Delete
bindkey '^[[1;5C' forward-word                    # Ctrl+Right
bindkey '^[[1;5D' backward-word                   # Ctrl+Left
bindkey '^H' kill-whole-line                      # Ctrl+Backspace

# edit command line in $EDITOR (nvim). ctrl+e is the primary bind; ctrl+x ctrl+e
# stays as the zsh-default fallback. note: ctrl+e was end-of-line in emacs mode —
# that jump is now edit-command-line; use ctrl+a then the arrow, or just edit.
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^E' edit-command-line
bindkey '^X^E' edit-command-line

####################################################################
# 🛑 the OSC SINK is settled HERE — OUTSIDE the `[[ -t 1 ]]` block below
#
# ⚠️ .this line looks like it belongs beside the emitters, and it does NOT
#    every writer that reaches for `$_osc_sink` is a `chpwd` hook, and a
#    `chpwd` hook fires on every `cd` — a `cd` inside a `$( )` among them,
#    where fd 1 is a PIPE and `[[ -t 1 ]]` is FALSE.
#
#    ⇒ so a sink declared inside that block is UNSET at the one moment it is
#      most needed, and `>$_osc_sink` then redirects to an EMPTY filename.
#
# 📜 measured 2026-09-14, after the sink was first placed inside the block:
#
#      $ zsh -ic true | wc -c
#      _grove_fnm_use_on_cd:2: no such file or directory:
#      0
#
#    the byte count went green and the shell still spoke — on stderr, where
#    the count could not see it. a clamp that reads one stream is half a
#    clamp (`gotcha.a-check-that-cries-wolf-gets-silenced`).
#
# ⚠️ `_grove_fnm_use_on_cd` is the reader that proved it: it sits in the
#    `command -v fnm` block far below, which has NO tty gate of its own, so
#    it runs under a pipe while the sink's own block does not.
#
# ⚠️ `; }`, never `{ … }` — zsh accepts the bare form and bash does NOT: it
#    reads the `}` as an argument to `:`, leaves the group unterminated, and
#    reports the error a hundred lines later at an innocent `fi`. this file is
#    read by `prove.dual-shell-files-hold-no-bash-only-syntax`, so it must
#    parse under both (`rule.forbid.bare-globs-in-dual-shell-files`, same seam)
#
# ⚠️ `-w /dev/tty` is NOT the probe: `access(2)` reads the device node's mode
#    bits, which say `crw-rw-rw-` on a box with no ctty as readily as on one
#    with. only an OPEN answers, so this opens it.
####################################################################
_osc_sink=/dev/null
{ : >/dev/tty; } 2>/dev/null && _osc_sink=/dev/tty

# interactive session setup
if [[ -t 1 ]]; then
  # disable ctrl+z job suspend (lets apps like nvim use ctrl+z for undo)
  stty susp undef

  # grove.provision:4.3.1.terminfo
  # .what = erase on ^? (DEL, 0x7f), which is what kitty and every modern terminal send
  # .why  = when the tty erases on ^H instead, backspace is echoed rather than acted
  #         on, and an unhandled erase is drawn as a SPACE
  #
  # ⚠️ .why this line is DECLARED here rather than appended by 4.3.1.terminfo
  #      `2.5.zsh` owns ~/.zshrc by BYTE — its configure.upsert `cp`s this file over
  #      the live one, and its configure.verify demands `cmp -s` equality, so that a
  #      stale rc is caught rather than silently kept. any other bundle that appends
  #      to ~/.zshrc therefore breaks that verify on the very next run.
  #
  #      📜 measured on grove-1 2026-07-31, with 4.3.1.terminfo appended here:
  #      a full-tree run left `2.5.zsh`'s plan at
  #      `✋ ~/.zshrc DIFFERS from the checkout` PERMANENTLY — apply it and terminfo
  #      re-appends on the next pass. worse, terminfo itself never went red, because
  #      its verify accepts the marker in EITHER rc and ~/.bashrc still carried it.
  #      so one bundle quietly broke another's claim and paid no price for it.
  #
  #      the marker comment above is kept verbatim: 4.3.1.terminfo's configure.verify
  #      greps both rc files for it, so the declaration is still proven by the bundle
  #      whose concern it is. terminfo keeps ~/.bashrc, which no bundle byte-owns
  [[ -t 0 ]] && stty erase '^?' 2>/dev/null

  ####################################################################
  # 🛑 the OSC SINK — the TERMINAL, never stdout
  #
  # ⚠️ .this assignment is DUPLICATED at the top of the file, ON PURPOSE
  #    the copy above is the one that binds; this one is dead on every run.
  #    it is kept so a reader who lands on the emitters below finds the sink's
  #    whole reason beside them rather than 60 lines up, and re-assignment is
  #    idempotent, so the pair cannot disagree. ⇒ see the top copy for WHY it
  #    must sit outside this `[[ -t 1 ]]` block.
  #
  # 📜 measured 2026-09-14. both emitters below `printf`ed to STDOUT, and
  #    both are `chpwd` hooks. so ANY `cd` inside a command substitution
  #    poured their escape bytes straight into the capture:
  #
  #      eval "$( cd "$HOME"; pnpm completion zsh )"
  #        ✋ (eval):1: command not found: ^[]7
  #        ✋ (eval):1: no such file or directory: file://pop-os/home/vlad^G^[]2
  #        ✋ (eval):1: command not found: ~^G#compdef
  #
  #    read the payloads and the cause is on the page: the OSC 7 body is
  #    `$HOME`, the OSC 2 title is `~`, and `#compdef` is the first line of
  #    `pnpm completion zsh` — three unrelated producers, glued into one
  #    string, and RUN in the human's interactive shell.
  #
  # ⇒ an OSC sequence addresses the TERMINAL. a capture is not one. so the
  #   sink is `/dev/tty`, which stays the terminal where fd 1 is a pipe —
  #   and that holds for every future `cd` inside a `$( )` rather than for
  #   one call site at a time (`rule.require.solve-at-cause`).
  #
  # ⚠️ a process with no ctty opens no `/dev/tty`, so the sink is settled
  #    ONCE here rather than probed per `cd` — these run on every directory
  #    change, and `.perf` is why they are hooks at all.
  #
  # ⚠️ `-w /dev/tty` is NOT the probe: `access(2)` reads the device node's
  #    mode bits, which say `crw-rw-rw-` on a box with no ctty as readily as
  #    on one with. only an OPEN answers, so this opens it.
  ####################################################################
  # ⚠️ `; }`, never `{ … }` — zsh accepts the bare form and bash does NOT: it
  #    reads the `}` as an argument to `:`, leaves the group unterminated, and
  #    reports the error a hundred lines later at an innocent `fi`. this file is
  #    read by `prove.dual-shell-files-hold-no-bash-only-syntax`, so it must
  #    parse under both (`rule.forbid.bare-globs-in-dual-shell-files`, same seam)
  _osc_sink=/dev/null
  { : >/dev/tty; } 2>/dev/null && _osc_sink=/dev/tty

  # report cwd to the terminal, so a new tab or split inherits this pwd —
  # kitty reads OSC 7 for `launch --cwd=current`, as does every other emulator
  # that offers the feature. uses the OSC 7 escape with a URL-encoded path
  #
  # 🛑 a DIRECTORY NAME is untrusted input, and this puts it inside an OSC string
  #
  # .why  = a linux directory name may hold ANY byte but `/` and NUL — a BEL
  #         (`\a`) among them, and BEL is what ENDS this OSC 7 string. so a dir
  #         named `x<BEL><ESC>]52;c;<b64><BEL>` closes the cwd report and hands
  #         the terminal a fresh OSC 52, which — with `set-clipboard on` in
  #         `src/tmux.conf` — WRITES THIS HUMAN'S CLIPBOARD. the next paste is a
  #         command a grove chose and a human vouched for.
  #
  #         ⇒ and the tree is REACHABLE: `git.grove.pull` writes a tree the
  #           GROVE named into `--into`, and the human then `cd`s in to read it.
  #           this fires on every `cd`, so it needs no other step at all.
  #
  # ⚠️ a `// /%20` ALONE encodes SPACES only. a space is the cosmetic case; the
  #    control bytes are the whole hazard, and that form lets them through
  #    (`gotcha.a-check-that-cries-wolf`, m.12 — a reader that matches a SUBSET
  #    reports the subset as the whole).
  #
  # ⚠️ a PARAMETER EXPANSION, never `__duct_strip_escapes`
  #    this runs on every `cd`. the sink is three processes; `${x//[[:cntrl:]]/}`
  #    is none, and it cuts every byte that can END this OSC 7 string — BEL and
  #    ESC are both C0, and C0 is what `[[:cntrl:]]` reaches first.
  #
  # 🛑 .the BOUND of `[[:cntrl:]]`, MEASURED 2026-08-31 — it does NOT reach C1
  #      one payload (`x\a\e]52;c;ZXZpbA==\a\177\302\233Y\233Z`), one utf-8
  #      locale, `//`:
  #
  #        zsh 5.9   left a bare `9b`            (it DID cut the encoded `c2 9b`)
  #        bash 5.2  left `c2 9b` AND bare `9b`  (it cut neither form)
  #
  #      ⇒ so the residue HERE is one byte: a raw `9b` in a directory name. a
  #        utf-8 terminal reads that as invalid utf-8 and draws U+FFFD, so it
  #        drives no sequence — and kitty is utf-8 only. the guard is therefore
  #        sufficient for ITS OWN subject, and any claim of "covers C0, DEL and
  #        C1" is wider than its reach
  #        (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.4).
  #
  #      🛑 and the bash row is why this bound is written down rather than
  #         shrugged off: `src/bash_aliases.sh` is sourced by BOTH shells, so
  #         this primitive is WRONG there and that file uses the sink instead.
  #         a reader who trusts the wider claim carries a zsh-measured fact
  #         into a bash file (`term=holder`).
  _osc7_cwd() {
    local safe="${PWD//[[:cntrl:]]/}"
    local url_path="${safe// /%20}"  # encode spaces (common case)
    printf '\e]7;file://%s%s\a' "${HOST:-localhost}" "$url_path" >$_osc_sink
  }
  chpwd_functions+=(_osc7_cwd)
  _osc7_cwd  # run once on shell start

  # set terminal title to "repo:branch/subpath" within a repo, else the pwd
  # subpath is the dir relative to repo root (e.g. repo:branch/src); omitted at root
  # uses OSC 2 escape sequence for window/tab title
  _set_terminal_title() {
    local title repo="" branch=""
    if git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
      repo=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
      branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
      local branchsuffix=".${branch//\//.}"                      # worktree dir convention: repo.branch-with-slashes-as-dots
      repo="${repo%$branchsuffix}"                               # drop redundant branch suffix (e.g. dev-env-setup.vlad.fix-kitty-titles -> dev-env-setup)
      local subpath="$(git rev-parse --show-prefix 2>/dev/null)"  # e.g. "src/foo/" ("" at root)
      subpath="${subpath%/}"                                      # drop the "/" suffix
      title="${repo}:${branch}${subpath:+/$subpath}"             # append /subpath only if set
    else
      title="${PWD/#$HOME/~}"  # home-abbreviated pwd
    fi
    # 🛑 same hazard, second emitter — `$title` is built from a repo BASENAME, a
    #    branch, and a SUBPATH, and two of those three are directory names. a
    #    BEL in one ends this OSC 2 and the rest is fresh terminal input. the
    #    full reason sits on `_osc7_cwd` above
    printf '\e]2;%s\a' "${title//[[:cntrl:]]/}" >$_osc_sink

    # inside tmux, push repo + branch as pane options so the tmux status line can
    # read them directly (see status-left/right in tmux.conf) — no string parse,
    # no git subprocess on a status refresh. outside a repo these are empty, so the
    # status line clears rather than show a stale repo/branch. branch here is clean
    # (no subpath), so the status-right shows only the branch.
    # ⚠️ stripped here too: these land in tmux's status line, which is a second
    #    path to the same terminal. one rule, every emitter — a strip on two of
    #    three sites is the gap m.9 names
    if [[ -n "$TMUX" ]]; then
      tmux set -p @repo "${repo//[[:cntrl:]]/}" 2>/dev/null
      tmux set -p @branch "${branch//[[:cntrl:]]/}" 2>/dev/null
    fi
  }
  chpwd_functions+=(_set_terminal_title)
  precmd_functions+=(_set_terminal_title)  # re-assert on every prompt (restores title after apps like nvim exit)
  _set_terminal_title  # run once on shell start

  # completions: rebuild only if completion files changed
  # ref: https://gist.github.com/ctechols/ca1035271ad134841284
  #
  # security note: we run full compinit (with compaudit security check) on cache miss,
  # only skipping the audit on cache hit when files haven't changed. this ensures new
  # or modified completion files are always security-checked before being trusted.
  autoload -Uz compinit
  zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
  if [[ -f "$zcompdump" ]] && ! find /usr/share/zsh/functions/Completion -newer "$zcompdump" -quit 2>/dev/null | grep -q .; then
    compinit -C              # cache hit: skip security check (files unchanged)
  else
    compinit                 # cache miss: full rebuild with security audit
    zcompile "$zcompdump" 2>/dev/null  # compile for faster loading
  fi

  # completion style
  zstyle ':completion:*' menu select                    # arrow key menu
  zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'   # case-insensitive

  # fzf keybindings (Ctrl+R for history, Ctrl+T for files, Alt+C for cd)
  [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh

  # up/down prefix search (after fzf so these take precedence)
  bindkey '^[[A' history-beginning-search-backward  # Up (normal mode)
  bindkey '^[[B' history-beginning-search-forward   # Down (normal mode)
  bindkey '^[OA' history-beginning-search-backward  # Up (application mode)
  bindkey '^[OB' history-beginning-search-forward   # Down (application mode)

  ######################################################################
  # emoji: ':turt<TAB>' -> 🐢, ':zap:' -> ⚡, ':zap<Enter>' -> emoji zap
  #
  # it must load AFTER compinit (it wraps a completion widget) and AFTER
  # fzf (so our TAB bind takes precedence) — the same order discipline
  # the up/down binds above follow.
  #
  # ⚠️ zsh only. it calls `zle` and `bindkey`, which bash has none of, so
  #    it cannot live in ~/.bash_aliases — BASH_ENV (set below) makes bash
  #    source that file in non-interactive shells too.
  #
  # ⚠️ the `-f` guard is load-bear, not defensive habit. `2.9.emoji`
  #    DECLINES on a box with no human, so a grove holds no such file and
  #    must source none — the guard is what keeps this line silent there
  #    rather than an error in every duct pane.
  ######################################################################
  [[ -f ~/.zshrc.emoji.sh ]] && source ~/.zshrc.emoji.sh
fi

# aliases
# note: ~/.bash_aliases sources ductwork + termwork itself, so zsh gets them via this
source ~/.bash_aliases

# make bash subshells (e.g., scripts, git aliases, makefiles) also load aliases
# zsh sources ~/.bash_aliases above, but bash subshells spawned from zsh won't
# BASH_ENV tells bash to source this file on startup for non-interactive shells
export BASH_ENV=~/.bash_aliases

# user private bins
if [ -d "$HOME/.local/bin" ] ; then
 PATH="$HOME/.local/bin:$PATH"
fi

# fnm (fast node manager) — its PATH dirs AND its env eval are declared in
# ~/.zshenv, because a PROGRAM-invoked shell needs node just as much as a
# human's does. what stays here is the interactive half: the chpwd hook.
#
# 🛑 .`eval "$(fnm env)"` stood HERE until 2026-09-19 — 📜 issue #140
#
#    it moved because `fnm use` needs `FNM_MULTISHELL_PATH`, and an rc reaches
#    a human's shell alone — so every agent, cron and jest child on the box
#    died at `fnm: command not found` while a keyboard found it healthy.
#
# ⚠️ and it is NOT kept here as a belt to that brace. zsh sources `.zshenv`
#    BEFORE this file, always — so a copy here would fork a second time and
#    mint a SECOND per-shell dir on every interactive shell, over a var that
#    already holds one (`rule.forbid.two-writers-on-one-artifact`). the guard
#    in `.zshenv` is keyed on that var, and this is what keeps it honest.
if command -v fnm &>/dev/null; then

  # ⚠️ .why this hook is written here rather than taken from `fnm env --use-on-cd`
  #      the generated hook calls `fnm use --silent-if-unchanged`, and NOT
  #      `--install-if-missing`. so when a repo's `.nvmrc` pins a version the box
  #      does not hold, fnm neither falls back nor fails — it ASKS, on stdin,
  #      inside whatever shell did the `cd`:
  #
  #        Can't find an installed Node version matching v22.21.0.
  #        Do you want to install it? answer [y/N]:
  #
  #      measured on grove-1 2026-08-03, on a plain `cd` into a checkout. that
  #      call sat for 4m16s. a duct IS tmux, so the question holds the pane and
  #      then consumes the NEXT command sent down the duct as its answer — so the
  #      damage is not a slow shell, it is a corrupted command stream, and it
  #      surfaces as some later command that did the wrong work
  #      (`rule.forbid.tty-as-a-proxy-for-a-human`)
  #
  #      `5.1.node` installs a baseline of versions so this repo never trips it,
  #      but a baseline can only ever cover the repos we know. every repo a grove
  #      clones brings its own `.nvmrc`, so the hook itself must be incapable of
  #      a prompt — the baseline narrows the odds, this closes the hole
  #
  # ⚠️ .why our OWN function name, rather than an override of `_fnm_autoload_hook`
  #      to redefine fnm's generated function after the eval would work today and
  #      break silently the day fnm renames it — the prompt would simply return,
  #      on a box nobody watches. a hook we name is a hook no upstream rename can
  #      quietly unhook (`rule.require.solve-at-cause`)
  #
  # .why the guard matches fnm's own
  #      fnm switches when any of `.node-version`, `.nvmrc`, or `package.json` is
  #      present (the last via `engines.node`, which `FNM_RESOLVE_ENGINES` enables
  #      by default). the same three are tested here so behavior is unchanged
  #      apart from the prompt
  #
  # 🛑 .the RESIDUE — a prompt is what this closed, and it is not the only hazard
  #      the three files above are DATA, and `git.grove.pull` lands a remote tree
  #      at a path its caller names. `GROVE_BOUNDARY_EXCLUDES` is `.git
  #      node_modules .log .temp .agent/.cache` (`git.grove.operations.sh:141`),
  #      so a `.node-version`, a `.nvmrc`, and a `package.json` all ride the
  #      inbound path untouched, whatever the grove wrote in them.
  #
  #      ⇒ so a grove picks WHICH NODE THE LAPTOP FETCHES AND THEN RUNS. one `cd`
  #        into a landed tree and `--install-if-missing` acquires the pinned
  #        build — an old release with published CVEs is a legal pin. a
  #        `{"engines":{"node":"12.0.0"}}` suffices, since `FNM_RESOLVE_ENGINES`
  #        is on by default, so a bare `package.json` is enough to pin.
  #
  #      ⚠️ .the REACH is the SHELL SESSION, never merely "under that dir"
  #        the hook has an entry arm and **no revert arm**, and `fnm use`
  #        re-points the per-shell `FNM_MULTISHELL_PATH` symlink. so a `cd` OUT
  #        of the landed tree runs no part of this, and the grove's pin holds
  #        for **the rest of that shell session** — in the human's own repos,
  #        not under the pulled dir.
  #
  #      🛑 .and do NOT "fix" that by an else-arm that reverts to the default
  #        this same hook is what makes a legitimate per-repo pin work. a revert
  #        arm would fire on every `cd` out of every CORRECT checkout — the whole
  #        of `~/git`, hundreds of transitions a day — so it would argue with
  #        correct behaviour far more often than with this residue (q7).
  #
  #      the bound that holds: fnm fetches from nodejs.org's own dist feed, and
  #      the mirror is an ENV var (`FNM_NODE_DIST_MIRROR`), which a pulled FILE
  #      cannot set. so a grove chooses the VERSION, never the SOURCE.
  #
  # ⚠️ .do NOT "fix" this with a timeout around the `fnm use` below
  #      fnm's fetch was measured BOUNDED on 2026-08-14, so a wrapper would add a
  #      second bound over a call that already has one — a false ✋ with a
  #      plausible fix, which is the costliest kind
  #      (`gotcha.a-check-that-cries-wolf-gets-silenced`, q7). the residue above
  #      is about WHICH version is chosen, and no timeout reaches that.
  # 🛑 `>$_osc_sink` — the THIRD stdout writer of the 2026-09-14 repair, and the
  #    one the first two passes missed. measured, not recalled:
  #
  #      $ zsh -ic true | wc -c
  #      20
  #      $ zsh -ic true | cat -A
  #      Using Node v22.21.0$
  #
  #    `fnm use` prints that line to STDOUT whenever the version changes, and
  #    `--silent-if-unchanged` only quiets the no-op case. two harms, one cause:
  #
  #      1. it is a BOOT PRINT. a shell that opens inside a pinned repo leads
  #         with it, and a human is asked to act on none of it
  #      2. ⚠️ this function is a `chpwd` hook, so it is the SAME junction the
  #         OSC emitters sat on — any `cd` inside a `$( )` that lands in a
  #         pinned tree pours this line into the capture
  #
  #    ⇒ so the repair is the repair the OSC emitters already got: the line
  #      addresses a HUMAN AT A TERMINAL, and a capture is not one. it goes to
  #      the sink settled once at boot, which stays the terminal even where fd 1
  #      is a pipe.
  #
  # ⚠️ STDOUT only — stderr is left alone on purpose. an absent version, a failed
  #    fetch, and a refused install all report there, and to sink those would be
  #    a failhide (`rule.forbid.failhide`).
  _grove_fnm_use_on_cd() {
    [[ -f .node-version || -f .nvmrc || -f package.json ]] || return 0
    fnm use --install-if-missing --silent-if-unchanged >$_osc_sink
  }
  autoload -U add-zsh-hook
  add-zsh-hook -D chpwd _grove_fnm_use_on_cd
  add-zsh-hook chpwd _grove_fnm_use_on_cd

  # run once for the dir the shell STARTS in — `chpwd` fires on a change, and a
  # login shell that opens directly inside a pinned repo never changes dir
  _grove_fnm_use_on_cd

  # ensure pnpm available after fnm version switches
  _FNM_PNPM_CHECKED_VERSION=""
  _ensure_pnpm_after_fnm() {
    # only check when node version changes
    local current_version="${FNM_VERSION:-}"
    [[ "$current_version" == "$_FNM_PNPM_CHECKED_VERSION" ]] && return
    _FNM_PNPM_CHECKED_VERSION="$current_version"

    # fast path: pnpm works
    # CI=1 prevents corepack shim prompt (hangs in non-interactive context)
    #
    # ⚠️ run from $HOME — see the 🛑 on the install below. a `pnpm --version`
    #    under a corepack shim reads the nearest `package.json`, and its
    #    `packageManager` field names a version corepack FETCHES and RUNS. that
    #    field is grove-chosen in any pulled tree, and `CI=1` is what removes
    #    the consent prompt that would otherwise gate the download
    #
    # ⚠️ BOUNDED for the reason the install below states in full: a stall in a
    #    shell RC does not fail one phase, it WEDGES THE PANE. that rule is
    #    this block's own, and this line is the half that escapes it most
    #    easily — a corepack shim may FETCH here, so `--version` is a registry call
    #    whenever the cwd names a version the box does not hold (m.9: one rule,
    #    two halves, and the cheaper half is the one that drifts).
    #
    #    the literals are the clamped copy of `WEB_REGISTRY_{GRACE,TOTAL}` —
    #    never a third number (`prove.registry-bounds-agree`).
    #
    # 🛑 `cd -q`, here and at the install below — this function IS a `chpwd`
    #    hook, so a bare `cd` re-fires every hook in `chpwd_functions`, THIS
    #    ONE INCLUDED. a subshell bounds the blast and does not stop the
    #    re-entry, and each round forks again.
    #    ⇒ `-q` suppresses `chpwd` and `chpwd_functions`, which is correct on
    #      its own terms too: this cwd is CONTAINMENT, never a place a human
    #      went, so no hook that reacts to a human's move belongs on it.
    #
    #    📜 measured 2026-09-14 rather than recalled — one counter, one hook:
    #         bare cd  -> fired=1
    #         cd -q    -> fired=1      ← the hook did not run
    #      `prove.rc-hooks-never-reach-a-capture` re-proves it on every box.
    ( cd -q "$HOME" && CI=1 timeout -k 30 900 pnpm --version ) &>/dev/null && return

    # install pnpm globally (works on node <25 and 25+)
    #
    # ⚠️ BOUNDED, and this is the sharpest bound in the repo — measured
    #    2026-08-14, `npm install` against a listener that accepts and stays
    #    silent NEVER returned, cut at 240s over 2 attempts.
    #
    #    this line does not sit in a bundle. it sits in a shell RC, so it runs
    #    on every shell START and after every `cd`. a duct pane IS a shell, so
    #    an unbounded stall here does not fail one phase — it wedges the pane,
    #    and every command sent down that duct afterward queues behind it.
    #
    #    the shape is the two-layer bound from `src/grove.web.sh`:
    #      · --fetch-timeout — a PER-REQUEST cutoff, so a dead registry dies on
    #        its first request rather than at the total
    #      · timeout -k — the TOTAL backstop, so the call is guaranteed to RETURN
    #
    # 🛑 the `-k 30` is not decoration; it is the half that makes 900 a BOUND.
    #    a bare `timeout` sends TERM, and a package manager mid-transaction may
    #    ignore TERM to protect its store — measured 2026-08-14, a bare timeout
    #    did NOT end a TERM-deaf child at five times its limit, while `-k` ended
    #    it on the dot (`prove.timeouts-kill-what-they-cut`). on this line, a
    #    bound that cannot end its child wedges the pane it runs in
    #
    # ⚠️ these two numbers are a COPY of `WEB_REGISTRY_*_SECONDS`, deliberately.
    #    a shell RC must work on a box with no checkout, so it cannot source the
    #    boundary — the same exemption `grove.bootstrap.sh` holds, and the same
    #    hazard: an exempt artifact escapes the sweep that enforces the rule.
    #    so the copy is CLAMPED — `prove.registry-bounds-agree` reads both files
    #    and refuses a disagreement.
    # 🛑 ROOTED AT $HOME — a package manager reads its CONFIG from the CWD.
    #    this is a `chpwd` hook, so the CWD at this moment is whatever dir the
    #    human just entered — and on a laptop that dir is routinely a tree a
    #    grove wrote (`git.grove.pull` lands one). so the CWD is REMOTE-CHOSEN
    #    input, and it reaches this call as CONFIGURATION rather than as an
    #    argument:
    #      · a project `.npmrc` on the path names the REGISTRY this fetch asks,
    #        and `_authToken` for it
    #      · a `packageManager` field in the nearest `package.json` names a
    #        version a corepack shim FETCHES and EXECUTES
    #      · `CI=1` is what removes the consent prompt that would gate that
    #        download, so the grant this line makes for the stall is also the
    #        grant that makes the fetch silent
    #
    #    ⇒ the subshell is the fix, and it must be a SUBSHELL, not a bare `cd`:
    #    this is a hook in an INTERACTIVE shell, so a bare `cd` would move the
    #    human's own dir out from under them.
    # 🛑 PINNED, and `--ignore-scripts`. a bare `npm install -g pnpm` is
    #    `pnpm@latest`, in the one repo whose own bundle refuses that by name:
    #
    #      5.1.node/provision.upsert.sh:347 — ".why an undeclared pin is a HARD
    #      stop rather than a fall back to `@latest` — a fall back would restore
    #      the exact defect on any repo declapract has yet to stamp, and it
    #      would do so silently"
    #
    #    ⚠️ and `npm` is NOT pnpm 10. pnpm is deny-by-default on lifecycle
    #       scripts, which is why `5.3.brains` can name a single
    #       `--allow-build=`. npm RUNS them — so whoever publishes `pnpm` to
    #       the registry had code execution here, on shell start and on every
    #       `cd` into a repo whose pinned node version has no pnpm beside it.
    #
    # ⚠️ the literal is a COPY of this repo's `packageManager` field, for the
    #    same reason the two `WEB_REGISTRY_*` numbers above are copies: an RC
    #    must work on a box with no checkout, so it cannot source the boundary.
    #    the copy is a FLOOR for the fallback path only — `5.1.node` still
    #    installs the per-repo declared version, and that remains the pin that
    #    governs a converged box.
    # 🛑 the clamp for THIS copy is OWED, not claimed. `prove.registry-bounds-agree`
    #    reads the two second-counts and does not read this. do not read the
    #    absence of a ✋ here as agreement.
    local _pnpm_floor="10.24.0"
    echo "• pnpm not found, install pnpm@$_pnpm_floor via npm..." > /dev/tty
    ( cd -q "$HOME" && CI=1 timeout -k 30 900 \
        npm install -g "pnpm@$_pnpm_floor" --ignore-scripts --fetch-timeout 60000 ) > /dev/tty 2>&1
  }

  # run on shell start + after every cd (when fnm may switch versions)
  _ensure_pnpm_after_fnm
  chpwd_functions+=(_ensure_pnpm_after_fnm)

  ####################################################################
  # 🛑 pnpm completions — ROOTED AT $HOME, for the reason the 🛑 above gives,
  #    and this line needed it MOST — measured 2026-09-01
  #
  #    it is the THIRD `pnpm` call in this block and it got NONE of the
  #    containment the other two carry. the header at `.ROOTED AT $HOME` spells
  #    out why the cwd is remote-chosen input to a package manager, eight lines
  #    up, and this line sat below it with a bare call.
  #
  #    ⚠️ and it is the one that pipes the result into `eval`. its two siblings
  #      send stdout to `&>/dev/null` and read only the exit code; this one
  #      takes the BYTES and runs them in the human's interactive shell.
  #
  #    the cwd reaches it as CONFIG, not as an argument:
  #      · a `packageManager` field in the nearest `package.json` names the
  #        version a corepack shim FETCHES and RUNS — and that program's stdout
  #        is what `eval` then executes
  #      · a project `.npmrc` names the registry that fetch asks
  #
  #    ⚠️ .the cwd here is the SHELL'S START cwd, not a `chpwd` hook's
  #      so the reachable path is any launcher that roots a new shell at an
  #      inherited dir. this repo ships four: `tmux.conf:82`
  #      (`respawn-pane -c '#{pane_current_path}'`), kitty's
  #      `launch --cwd=current`, its `boss.launch(--cwd=…)`, and `duct.reboot`.
  #      a human who `cd`s into a pulled tree and opens a pane is the whole
  #      trigger — no deliberate command is needed.
  #
  # 🛑 `[[ -t 1 ]]` makes this WORSE, not safer: it guarantees the line runs
  #    exactly where a corepack consent prompt is most costly. a duct pane IS a
  #    tty, and a prompt there wedges the pane and eats every command sent after
  #    it (`rule.forbid.tty-as-a-proxy-for-a-human`). `CI=1` removes the prompt.
  #
  # ⚠️ the `eval` stays OUTSIDE the subshell on purpose — a completion defines
  #    functions, and functions defined inside `( … )` die with it.
  #
  # 🛑 `cd -q`, never a bare `cd` — the SECOND half of the 2026-09-14 repair
  #    `-q` suppresses `chpwd` and `chpwd_functions`, and four hooks are
  #    registered by the time this line runs: the two OSC emitters above,
  #    `_grove_fnm_use_on_cd`, and `_ensure_pnpm_after_fnm`. not one of them
  #    is wanted here — this cwd is CONTAINMENT, never a place the human went.
  #
  #    ⇒ the OSC sink above already keeps their bytes out of this capture, so
  #      this is the belt to that brace. it earns its own line because it
  #      closes a SECOND hazard the sink does not reach: `_grove_fnm_use_on_cd`
  #      would switch this shell's node version mid-capture, from a `.nvmrc`
  #      the cwd chose — and `pnpm` is a node program.
  ####################################################################
  [[ -t 1 ]] && command -v pnpm &>/dev/null && eval "$(
    cd -q "$HOME" || exit
    export CI=1
    timeout -k 30 900 pnpm completion zsh 2>/dev/null \
      || timeout -k 30 900 pnpm completion bash 2>/dev/null
  )"
fi

# deeno!
export DENO_INSTALL="$HOME/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"

# use nvim by default in terminal
export VISUAL=nvim
export EDITOR="nvim"

# ⚠️ the aws env moved to `~/.zshenv` on 2026-08-06 — see src/zshenv.sh
#
#    `AWS_SDK_LOAD_CONFIG=1` lived here for years. `AWS_PROFILE=ambient` was
#    added here and lasted one run: grove-1's integration suite still died with
#    `AWS_PROFILE not set` while the export sat, correct and readable, in this
#    file.
#
#    zsh sources an RC for INTERACTIVE shells only. the test process was a
#    non-interactive shell, and so are `zsh -c`, `sg docker -c`, npm scripts,
#    and jest. an env pointer a PROGRAM must read belongs in `.zshenv`, which
#    every zsh sources.
#
#    this rc keeps what a HUMAN's shell needs — prompt, aliases, keybinds.

# rust
#
# ⚠️ this is the HUMAN's copy. `~/.cargo/env` sets more than PATH (it exports
#    the rustup shims a human's `rustc`/`rustup` calls want), so it stays here —
#    but the PATH half is ALSO declared in `~/.zshenv`, because `tree-sitter` is
#    a tool a PROGRAM must find (nvim-treesitter shells out to it), and this rc
#    is read by an interactive shell alone. see `src/zshenv.sh`, and the note 10
#    lines above that says exactly this and did not hold for cargo.
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# pnpm link --global
#
# ⚠️ .why BOTH $PNPM_HOME and $PNPM_HOME/bin — 📜 measured grove-1, 2026-08-02
#      `~/.profile` (owned by `5.1.node`'s configure) and that bundle's own
#      provision phase BOTH name the pair. name only $PNPM_HOME here and one
#      PATH claim carries three declarations with one in disagreement — and the
#      one that disagrees is the shell a DUCT lands in.
#
#      the cost: `pnpm install -g rhachet` refused in a duct with
#        [ERROR] The configured global bin directory
#                "/home/camper/.local/share/pnpm/bin" is not in PATH
#      while the same install ran clean inside a bundle. so an install repaired
#      itself under `grove.provision` and could not be repaired by hand, which
#      reads as "pnpm is broken" rather than as "this shell's PATH is short".
#
#      pnpm treats $PNPM_HOME itself as the global bin dir in some versions and a
#      /bin child in others; corepack reports the child. name both, and neither
#      refuses (`5.1.node/provision.upsert.sh` says the same, for the same reason)
#
# ⚠️ .why $PNPM_HOME/bin is prepended LAST, so it ends up FIRST — a TIEBREAK
#      one command can have TWO shims, because pnpm answers with both dirs, and
#      the stale one hardcodes a NODE_PATH at the old store layout and dies in
#      node's module loader once the packages move.
#
#      measured grove-1 2026-08-03: `~/.profile` named the bare dir first while
#      this file effectively named `/bin` first, so the two shells disagreed
#      about which `rhx` they meant — zsh ran, bash died with
#      `Cannot find module 'with-simple-cache'`. a DUCT is zsh and
#      `ssh -t 'bash -lc …'` is bash, so every duct-borne proof measured the
#      healthy shim while the one command a human runs got the broken one.
#
#      so the two prepends below are ORDER-SENSITIVE and must not be swapped for
#      tidiness: all three declarations of this PATH claim name one identical
#      order, which is what `rule.forbid.two-writers-on-one-artifact` asks.
#
# ⚠️ .why the order is a tiebreak and NOT the fix — the cause is the CWD
#      "only the `/bin` copy is refreshed by a current `pnpm install -g`" is
#      FALSE. grove-1 was asked directly on 2026-08-06
#      (`diagnose.pnpm-bin-dir-per-cwd`) and both answers came back within one
#      second of each other:
#
#        cwd = a repo   packageManager pnpm@10.24.0 → 10.24.0 → $PNPM_HOME
#        cwd = $HOME    no package.json above it    → 11.20.0 → $PNPM_HOME/bin
#
#      corepack's `pnpm` is a DISPATCHER: it runs the version the nearest
#      `packageManager` names, and its global default where none sits above the
#      cwd. so two pnpms write global shims to two dirs at the same instant, and
#      no order can name a single right one — only the caller's pnpm knows.
#
#      the fix is at the source: `5.1.node` pins corepack's global default to the
#      declared `packageManager` version, so both cwds converge on one dir, and
#      its prune clears the fossils a box already grew. these two prepends stay
#      because they make every shell agree while duplicates still exist
#      ⚠️ these prepends live in `~/.zshenv` (`src/zshenv.sh`), beside the fnm
#         dir above — every note here holds there: the two dirs, the order,
#         the corepack dispatcher.
#
#      the move is not tidiness. this rc is INTERACTIVE-ONLY, so `rhx` (a pnpm
#      global shim) was absent from `ssh <seat> '<cmd>'`, from cron, and from
#      every jest child — which forced `git.grove.operations.sh:_shell_at` to probe
#      each seat and pick `zsh -ic` to get a PATH that a plain `zsh -c` should
#      have carried. a one-command, non-interactive provision cannot rest on a
#      file only a human's shell reads
#      (`rule.require.one-command-provision`).
#
#      ⚠️ do NOT re-declare PNPM_HOME or its PATH prepends here. .zshenv is read
#         by every zsh, interactive ones included, so this file needs no copy —
#         and a second copy is the two-writers defect this repo has paid for
#         three times (`rule.forbid.two-writers-on-one-artifact`).

# starship prompt (only for interactive TTY sessions)
# skipped for: Claude Code, scripts, pipes — they don't need a prompt
[[ -t 1 ]] && eval "$(starship init zsh)"

# 🛑 .NO CLAUDE FLAG IS EXPORTED HERE — `5.3.brains` declares every one of them
#    in `~/.claude/settings.json`, and is the SOLE writer
#    (`rule.require.brain-config-has-one-home`)
#
# .what stood here until 2026-09-25, and why each left
#   | export | why it left |
#   |---|---|
#   | `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | read at `et6()`, per turn — long after settings load |
#   | `DISABLE_AUTOUPDATER` | read at `j96()` off `process.env`; claude's own `RtK()` writes it INTO settings |
#   | `DISABLE_UPDATES` | 🔴 DEAD — 0 refs in cli 2.1.87 |
#   | `DISABLE_INSTALLATION_CHECKS` | read at `$w6()`/`kFz()`, behind a react effect |
#
# ⚠️ two of these carried `note: must be exported in shell — the settings.json env
#    block is read too late`. neither cited a READ SITE, and both were false: `zd()`
#    assigns the settings `env` block into `process.env` at startup, unfiltered.
#    ⇒ a shelf claim with no read site beside it is a guess, and these two guesses
#      bought a two-writers split across three bundles
