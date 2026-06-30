# enable profiling if ZPROF=1 (usage: shelltest.profile)
[[ "$ZPROF" == "1" ]] && zmodload zsh/zprof

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

# edit command line in $EDITOR (ctrl+x ctrl+e)
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# interactive session setup
if [[ -t 1 ]]; then
  # disable ctrl+z job suspend (lets apps like nvim use ctrl+z for undo)
  stty susp undef

  # report cwd to terminal (enables new tab to inherit pwd in ptyxis, etc)
  # uses OSC 7 escape sequence with URL-encoded path
  _osc7_cwd() {
    local url_path="${PWD// /%20}"  # encode spaces (common case)
    printf '\e]7;file://%s%s\a' "${HOST:-localhost}" "$url_path"
  }
  chpwd_functions+=(_osc7_cwd)
  _osc7_cwd  # run once on shell start

  # set terminal tab title to repo:branch (or directory name if not in repo)
  # uses OSC 2 escape sequence for window/tab title
  _set_terminal_title() {
    local title
    if git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
      local repo=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
      local branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
      title="${repo}:${branch}"
    else
      title="${PWD##*/}"  # just the current directory name
    fi
    printf '\e]2;%s\a' "$title"
  }
  chpwd_functions+=(_set_terminal_title)
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

# fnm (fast node manager) - no lazy load needed, it's fast
export PATH="$HOME/.local/share/fnm:$PATH"
if command -v fnm &>/dev/null; then
  eval "$(fnm env --use-on-cd)"

  # ensure pnpm available after fnm version switches
  _FNM_PNPM_CHECKED_VERSION=""
  _ensure_pnpm_after_fnm() {
    # only check when node version changes
    local current_version="${FNM_VERSION:-}"
    [[ "$current_version" == "$_FNM_PNPM_CHECKED_VERSION" ]] && return
    _FNM_PNPM_CHECKED_VERSION="$current_version"

    # fast path: pnpm works
    # CI=1 prevents corepack shim prompt (hangs in non-interactive context)
    CI=1 pnpm --version &>/dev/null && return

    # install pnpm globally (works on node <25 and 25+)
    echo "• pnpm not found, install via npm..." > /dev/tty
    CI=1 npm install -g pnpm > /dev/tty 2>&1
  }

  # run on shell start + after every cd (when fnm may switch versions)
  _ensure_pnpm_after_fnm
  chpwd_functions+=(_ensure_pnpm_after_fnm)

  # pnpm completions
  [[ -t 1 ]] && command -v pnpm &>/dev/null && eval "$(pnpm completion zsh 2>/dev/null || pnpm completion bash)"
fi

# deeno!
export DENO_INSTALL="$HOME/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"

# use nvim by default in terminal
export VISUAL=nvim
export EDITOR="nvim"

# allow aws-sdks to load config (e.g., node.aws-sdk grab region from ~/.aws)
export AWS_SDK_LOAD_CONFIG=1

# rust
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# pnpm link --global
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# starship prompt (only for interactive TTY sessions)
# skipped for: Claude Code, scripts, pipes — they don't need a prompt
[[ -t 1 ]] && eval "$(starship init zsh)"
