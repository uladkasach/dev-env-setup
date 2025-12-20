# enable profiling if ZPROF=1 (usage: shelltest.profile)
[[ "$ZPROF" == "1" ]] && zmodload zsh/zprof

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# theme
ZSH_THEME="spaceship"

export SPACESHIP_TIME_SHOW=true
# export SPACESHIP_BATTERY_SHOW=always
export SPACESHIP_PROMPT_ORDER=(
  user          # Username section
  dir           # Current directory section
  host          # Hostname section
  git           # Git section (git_branch + git_status)
  package       # Package version
  node          # Node.js section
  rust          # Rust section
  docker        # Docker section
  aws           # Amazon Web Services section
  venv          # virtualenv section
  exec_time     # Execution time
  time          # Time stampts section
  line_sep      # Line break
  battery       # Battery level and status
  jobs          # Background jobs indicator
  exit_code     # Exit code section
  char          # Prompt character
)

# theme colors
export COLOR_PASTEL_YELLOW="#ffffba" # https://www.color-hex.com/color-palette/5361
export COLOR_PASTEL_BLUE="#bae1ff" # https://www.color-hex.com/color-palette/5361
export COLOR_PASTEL_GREEN="#baffc9" # https://www.color-hex.com/color-palette/5361
export COLOR_PASTEL_PURPLE="#E0BBE4" # https://www.schemecolor.com/pastel-color-tones.php
export COLOR_PASTEL_ORANGE="#ffdfba" # https://www.color-hex.com/color-palette/5361

export SPACESHIP_CHAR_COLOR_SUCCESS=$COLOR_PASTEL_GREEN
export SPACESHIP_TIME_COLOR=$COLOR_PASTEL_YELLOW
export SPACESHIP_EXEC_TIME_COLOR=$COLOR_PASTEL_YELLOW
export SPACESHIP_DIR_COLOR=$COLOR_PASTEL_BLUE
export SPACESHIP_GIT_SYMBOL=""
export SPACESHIP_GIT_BRANCH_COLOR=$COLOR_PASTEL_PURPLE
export SPACESHIP_PACKAGE_SYMBOL=""
export SPACESHIP_PACKAGE_COLOR=$COLOR_PASTEL_YELLOW
export SPACESHIP_NODE_COLOR=$COLOR_PASTEL_GREEN
export SPACESHIP_AWS_COLOR=$COLOR_PASTEL_ORANGE
export SPACESHIP_AWS_SYMBOL="☁️  "


# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

# Skip oh-my-zsh for non-TTY sessions (e.g., Claude Code, scripts, pipes)
if [[ -t 1 ]]; then
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

# fnm (fast node manager) - no lazy loading needed, it's fast
export PATH="$HOME/.local/share/fnm:$PATH"
if command -v fnm &>/dev/null; then
  eval "$(fnm env --use-on-cd --corepack-enabled)"

  # pnpm completions
  [[ -t 1 ]] && command -v pnpm &>/dev/null && eval "$(pnpm completion zsh 2>/dev/null || pnpm completion bash)"
fi

# deeno!
export DENO_INSTALL="$HOME/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"

# use vim by default in terminal
export VISUAL=vim
export EDITOR="vim"

# allow aws-sdks to load config (e.g., node.aws-sdk grab region from ~/.aws)
export AWS_SDK_LOAD_CONFIG=1

# rust
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
