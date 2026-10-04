# enable profiling if ZPROF=1 (usage: shelltest.profile)
[[ "${ZPROF:-}" == "1" ]] && zmodload zsh/zprof

# .refs = gotcha.2-5-zsh.demo=zshrc-hooks-and-the-osc-sink — every 🛑/⚠️ below, measured.
#   this is the HUMAN's shell; a path a PROGRAM needs lives in ~/.zshenv

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

# 🛑 the OSC SINK — the TERMINAL, never stdout — settled OUTSIDE the `[[ -t 1 ]]`
#    block: its writers are `chpwd` hooks, which fire inside a `$( )` too (m1, m2)
# ⚠️ `; }`, never a bare `}` — bash misparses the bare form (m1)
# ⚠️ an OPEN is the probe, never `-w`, which reads mode bits alone (m1)
_osc_sink=/dev/null
{ : >/dev/tty; } 2>/dev/null && _osc_sink=/dev/tty

# interactive session setup
if [[ -t 1 ]]; then
  # disable ctrl+z job suspend (lets apps like nvim use ctrl+z for undo)
  stty susp undef

  # grove.provision:4.3.1.terminfo
  # .what = erase on ^? (DEL, 0x7f), which is what kitty and every modern terminal send
  # ⚠️ DECLARED here, never appended by 4.3.1.terminfo — this file is owned by
  #    byte, and the marker above is what terminfo's verify greps (m3)
  [[ -t 0 ]] && stty erase '^?' 2>/dev/null

  # the sink again, beside its emitters — idempotent, so the pair cannot disagree (m1)
  _osc_sink=/dev/null
  { : >/dev/tty; } 2>/dev/null && _osc_sink=/dev/tty

  # report cwd to the terminal, so a new tab or split inherits this pwd —
  # kitty reads OSC 7 for `launch --cwd=current`
  # 🛑 a DIRECTORY NAME is untrusted input: a BEL in one ends this string and
  #    hands the terminal a fresh OSC 52. `[[:cntrl:]]` cuts C0 and reaches no
  #    C1 — sufficient here, WRONG in a bash file (m4)
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
    # 🛑 same hazard, second emitter — two of the title's three parts are dir names (m4)
    printf '\e]2;%s\a' "${title//[[:cntrl:]]/}" >$_osc_sink

    # inside tmux, push repo + branch as pane options so the status line reads them
    # directly — no string parse, no git subprocess per refresh. stripped too: the
    # status line is a second path to the same terminal (m4)
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

  # emoji: ':turt<TAB>' -> 🐢. after compinit and fzf; zsh only; the `-f` guard
  # keeps a grove, which holds no such file, silent (m11)
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

# fnm — its PATH and its `fnm env` eval live in ~/.zshenv; a copy here would mint
# a SECOND per-shell dir (m5). what stays here is the interactive cwd hook
if command -v fnm &>/dev/null; then

  # 🛑 OUR hook, never fnm's generated one — fnm's ASKS on stdin when a `.nvmrc`
  #    pins an absent version, and in a duct that question eats the next command
  # 🛑 the residue: a pulled tree's pin chooses which node is fetched, for the
  #    rest of the session. do NOT add a revert arm, nor a timeout (m5)
  # 🛑 stdout to the sink — a version switch prints a line, and this is a `chpwd`
  #    hook. stderr stays, since an absent version is a fact a human needs (m6)
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
  # 🛑 every call here is ROOTED at $HOME in a subshell — the cwd is config to a
  #    package manager, and a pulled tree chose it (m7)
  # 🛑 `cd -q`, since this IS a `chpwd` hook and a bare `cd` re-fires it (m7)
  # 🛑 BOUNDED by `timeout -k` — a stall in an rc wedges the pane. the numbers
  #    copy `WEB_REGISTRY_*`, clamped by `prove.registry-bounds-agree` (m7)
  _FNM_PNPM_CHECKED_VERSION=""
  _ensure_pnpm_after_fnm() {
    # only check when node version changes
    local current_version="${FNM_VERSION:-}"
    [[ "$current_version" == "$_FNM_PNPM_CHECKED_VERSION" ]] && return
    _FNM_PNPM_CHECKED_VERSION="$current_version"

    # fast path: pnpm works. CI=1 removes the corepack consent prompt
    ( cd -q "$HOME" && CI=1 timeout -k 30 900 pnpm --version ) &>/dev/null && return

    # install pnpm globally (works on node <25 and 25+)
    # 🛑 PINNED and `--ignore-scripts` — never `@latest`, and npm RUNS lifecycle
    #    scripts where pnpm denies them. the floor copies `packageManager`, and
    #    its clamp is OWED, not claimed (m7)
    local _pnpm_floor="10.24.0"
    echo "• pnpm not found, install pnpm@$_pnpm_floor via npm..." > /dev/tty
    ( cd -q "$HOME" && CI=1 timeout -k 30 900 \
        npm install -g "pnpm@$_pnpm_floor" --ignore-scripts --fetch-timeout 60000 ) > /dev/tty 2>&1
  }

  # run on shell start + after every cd (when fnm may switch versions)
  _ensure_pnpm_after_fnm
  chpwd_functions+=(_ensure_pnpm_after_fnm)

  # 🛑 pnpm completions — ROOTED at $HOME and `cd -q`, and this call needed it
  #    MOST: its bytes go to `eval`, and the start cwd can be a pulled tree a
  #    launcher inherited. the `eval` stays OUTSIDE the subshell, since the
  #    functions it defines would die with it (m8)
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

# ⚠️ the aws env lives in ~/.zshenv — an rc reaches an interactive shell alone

# rust — the HUMAN's copy: `~/.cargo/env` exports more than PATH. the PATH half
# is ALSO in ~/.zshenv, since a PROGRAM execs `tree-sitter` (m10)
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# ⚠️ PNPM_HOME and its PATH pair live in ~/.zshenv. do NOT re-declare them here —
#    a second copy is the two-writers defect, paid for three times (m9)

# starship prompt (only for interactive TTY sessions)
# skipped for: Claude Code, scripts, pipes — they don't need a prompt
[[ -t 1 ]] && eval "$(starship init zsh)"

# 🛑 NO CLAUDE FLAG IS EXPORTED HERE — `5.3.brains` declares every one in
#    `~/.claude/settings.json`, the SOLE writer, and claude copies that `env` block
#    into its process at startup (`rule.require.brain-config-has-one-home`;
#    the read site per retired export: `gotcha.5-3-brains.demo=one-home-consolidation`)
