# enable profiling if ZPROF=1 (usage: shelltest.profile)
[[ "$ZPROF" == "1" ]] && zmodload zsh/zprof

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# theme: starship (cross-shell prompt in rust)
# config: ~/.config/starship.toml (synced from src/starship.toml)
ZSH_THEME=""


# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

# Skip oh-my-zsh for non-TTY sessions (e.g., Claude Code, scripts, pipes)
if [[ -t 1 ]]; then
  # disable ctrl+z job suspend (lets apps like nvim use ctrl+z for undo)
  stty susp undef
  # speed up compinit: only rebuild if completion files changed
  # ref: https://gist.github.com/ctechols/ca1035271ad134841284
  #
  # security note: we run full compinit (with compaudit security check) on cache miss,
  # only skipping the audit on cache hit when files haven't changed. this ensures new
  # or modified completion files are always security-checked before being trusted.
  autoload -Uz compinit
  zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
  if [[ -f "$zcompdump" ]] && ! find /usr/share/zsh/functions/Completion ~/.oh-my-zsh/completions -newer "$zcompdump" -quit 2>/dev/null | grep -q .; then
    source "$zcompdump"   # cache hit: load compiled dump directly (skips compinit overhead)
  else
    compinit              # cache miss: full rebuild with security audit
    zcompile "$zcompdump" 2>/dev/null  # compile for faster loading
  fi

  # tell oh-my-zsh we already ran compinit
  skip_global_compinit=1
  source $ZSH/oh-my-zsh.sh
fi

# aliases
source ~/.bash_aliases

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
