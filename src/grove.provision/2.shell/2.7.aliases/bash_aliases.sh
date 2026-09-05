# ductwork — headless terminal streams
[[ -f ~/.bash_aliases.ductwork.sh ]] && source ~/.bash_aliases.ductwork.sh

# termwork — terminal window management
[[ -f ~/.bash_aliases.termwork.sh ]] && source ~/.bash_aliases.termwork.sh

# brains.auth — see + swap the claude subscription budget by oauth token
#
# ⚠️ every `src/X.sh` sourced from this head needs a pair in
#   `2.7.aliases/configure.upsert.sh`, or the file never reaches the box. the
#   `[[ -f ]]` guard makes that failure SILENT: an absent file is a no-op, so
#   the namespace simply does not exist and a human reads it as a broken tool.
#   `2.7.aliases/configure.verify.sh` reads its pairs array and asserts each
#   member is named here, so the two halves cannot drift apart unnoticed.
[[ -f ~/.bash_aliases.brains.auth.sh ]] && source ~/.bash_aliases.brains.auth.sh

# prefer nvim over vim/vi
alias vim='nvim'
alias vi='nvim'

# open notes
alias notes='nvim ~/git/notes/main.txt'

# copy paste
alias pbcopy='xclip -selection clipboard'
alias pbpaste='xclip -selection clipboard -o'

# copy uuid into clipboard
alias getuuid='uuidgen | tr -d "'"\n"'" | pbcopy && echo "'"  ✔ uuid was copied"'"'

# quick test alias
alias ju='npx jest -c jest.unit.config.(ts|js)'
alias ji='npx jest -c jest.integration.config.(ts|js)'
alias ja='npx jest -c jest.acceptance.config.(ts|js)'
alias jal='LOCALLY=true ja'

# quick terraform alias
alias tf='terraform'

# vim-style image viewer — see 4.6.pqiv, which installs pqiv + its keybinds
function nimg {
  if ! command -v pqiv &> /dev/null; then
    echo "error: pqiv not installed. run: rhx grove.provision --what 4.6.pqiv --mode apply"
    return 1
  fi
  pqiv "$@"
}

# yubikey-agent's ssh socket — see 5.9.yubikey, which installs the agent
#
# .why declared here rather than appended by an installer: an installer that
#      APPENDS this line to this very file writes from a machine step into the
#      repo (rule.require.repo-as-source-of-truth), at a hardcoded main-checkout
#      path. and an undriven installer exports on no box at all, so the agent is
#      unreachable everywhere it is installed.
if [[ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/yubikey-agent/yubikey-agent.sock" ]]; then
  export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/yubikey-agent/yubikey-agent.sock"
fi

# claude code config (expected: v2.1.87, beyond which hooks are truncated)
export ANTHROPIC_MODEL='claude-opus-5[1m]'
export CLAUDE_CODE_SKIP_UPDATE_CHECK=1

# aws profiles via keyrack
# usage: use.ahbode.prep [--owner <owner>]
_use_aws_profile() {
  local env="$1"
  shift
  local -a extra_args=()
  if [[ "$1" == "--owner" ]]; then
    extra_args=(--owner "$2")
  fi
  unset AWS_PROFILE
  rhx keyrack unlock --key AWS_PROFILE --env "$env" "${extra_args[@]}" || return 1
  export AWS_PROFILE=$(rhx keyrack get --key AWS_PROFILE --env "$env" "${extra_args[@]}" --output value)
  echo "• AWS_PROFILE=$AWS_PROFILE"
  echo "• for sdk v2 (no sso support), export creds: eval \$(aws configure export-credentials --profile $AWS_PROFILE --format env)"
}
function use.ahbode.test { _use_aws_profile test "$@"; }
function use.ahbode.prep { _use_aws_profile prep "$@"; }
function use.ahbode.prod { _use_aws_profile prod "$@"; }
function use.ahbode.camp { _use_aws_profile camp "$@"; }
function use.ahbode.root { _use_aws_profile sudo "$@"; }
function use.ahction.prod { _use_aws_profile prod "$@"; }
function use.whodis.prod { _use_aws_profile prod "$@"; }
function use.ehmpathy.test { _use_aws_profile test "$@"; }
function use.ehmpathy.demo { _use_aws_profile test "$@"; }
function use.ehmpathy.root { _use_aws_profile sudo "$@"; }
function use.aether.test { _use_aws_profile test "$@"; }
function use.aether.prep { _use_aws_profile prep "$@"; }
function use.aether.prod { _use_aws_profile prod "$@"; }
function use.aether.root { _use_aws_profile sudo "$@"; }

# ahbode 3rd-party credentials
alias use.ahbode.fastly='export FASTLY_API_KEY=$(op get item fastly.ahbode.apikey | jq -r .details.password)'
alias use.ahbode.yelp='export YELP_API_KEY=$( op get item 2jhey5edfilrwjwhjn6mvtk7au  | jq -r ".details.sections[1].fields[1].v" )'
alias use.ahbode.bannerbear='export BANNER_BEAR_API_KEY=$( op get item bannerbear.ahbode.apikey | jq -r .details.password)'
alias use.ahbode.googlecloudplatform.apikey='export GCP_API_KEY=$(op get item ahbode.googlecloudplatform.providerstorefronts.apikey | jq -r .details.password)'
alias use.ahbode.googlecloudplatform.keyfilejson='export GCLOUD_KEYFILE_JSON=$(op get item ahbode.googlecloudplatform.providerstorefronts.admin.serviceaccountkey | jq -r .details.password)'

# github token
alias use.github.admin='export GITHUB_TOKEN=$(op item get github.admin.pat --fields label=password --format json | jq -r .value)'

# terraform caching, for when on slow internet
alias use.terraform.caching='mkdir -p $HOME/.terraform.d/plugin-cache && export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"' # https://www.terraform.io/docs/cli/config/config-file.html#provider-plugin-cache

# networking utilities
alias use.mtu.1400='sudo ifconfig wlp113s0 mtu 1400' # for when you're on older infra networks; https://serverfault.com/a/670081/276221; https://www.cloudflare.com/learning/network-layer/what-is-mtu/

# make it easy to manually update the keymappings, in case they drop off for some reason
# swap left-alt and left-super via cosmic xkb config (e.g., for external mac keyboards)
# cosmic-config watches the file via inotify, so changes apply instantly
XKB_CONFIG="$HOME/.config/cosmic/com.system76.CosmicComp/v1/xkb_config"
use_keymap_altswap() {
  if grep -q 'altwin:swap_lalt_lwin' "$XKB_CONFIG" 2>/dev/null; then
    echo "• alt/super already swapped"
    return 0
  fi
  sed -i 's/options: Some("\(.*\)")/options: Some("\1,altwin:swap_lalt_lwin")/' "$XKB_CONFIG"
  echo "• alt/super swapped"
}
use_keymap_altboot() {
  sed -i 's/,altwin:swap_lalt_lwin//;s/altwin:swap_lalt_lwin,\?//' "$XKB_CONFIG"
  echo "• alt/super reset"
}
alias use.keymap.altswap='use_keymap_altswap'
alias use.keymap.altboot='use_keymap_altboot'

# make signing into onepass easier
alias op.signin='eval $(op signin)'

# quiet browser for xdg-open, gh, etc (installed via install_browser_command)
export BROWSER="$HOME/.local/bin/browser"
alias machine.logout='loginctl terminate-user "$USER"'

# 🛑 .there is no `machine.reboot`, and one must never be added back
#      it stood here as `systemctl reboot` — the same act as `power.restart`
#      with the `kitty.snap` removed. so the two were one concept under two
#      words, and the terser one silently discarded the window/pwd map that
#      `4.3.4.snapshot` exists to preserve
#
#      ⚠️ a synonym is usually just drift. this one had a COST, and the cost
#         was invisible: both verbs reboot, and only one comes back with your
#         terminals. `1.2.power`'s own fix-text recommended the lossy one
#
#      ⇒ the reboot is `power.restart`. `power.*` owns the power-state
#        transitions; `machine.*` owns the session-level acts beside it

# lock the session — the ONE control 3.3.desktop leaves armed on the keybind too
#
# .why it needs an alias at all, when the keybind works
#      the idle timers are off by design (`system.power.spec`), so this box never
#      locks itself. that makes the deliberate lock the only lock there is, and a
#      control with exactly one route wants that route reachable from the shell —
#      where a hand already is
alias machine.lock='loginctl lock-session'
alias use.screencast='flatpak run org.gnome.NetworkDisplays'

# diagnose problem processes
#
# the three finders come from `1.6.1.finders`; the two observers from
# `1.7.usage`. an alias here does NOT install its command — if one of these
# reports "command not found", the bundle has not been applied on this box:
#   grove.provision --what 1.6.1.finders --mode apply
#   grove.provision --what 1.7.usage --mode apply

_machine_usage_diagnose() {
  echo ""
  echo "🐈 lets hunt..."
  # spinner (first)
  echo "   │"
  machine_resource_procs_find_spinner 2>/dev/null | tail -n +2 | sed '1s/└─/├─/; s/^  /│ /; s/^/   /'
  # runaway (middle)
  echo "   │"
  machine_resource_procs_find_runaway 2>/dev/null | tail -n +2 | sed '1s/└─/├─/; s/^  /│ /; s/^/   /'
  # orphan (last)
  echo "   │"
  machine_resource_procs_find_orphan 2>/dev/null | tail -n +2 | sed 's/^/   /'
}
alias machine.usage.diagnose='_machine_usage_diagnose'
alias machine.usage.diagnose.spinner='machine_resource_procs_find_spinner'  # sustained high CPU 30+ min
alias machine.usage.diagnose.runaway='machine_resource_procs_find_runaway --full'  # high CPU/memory right now
alias machine.usage.diagnose.orphan='machine_resource_procs_find_orphan'    # cwd deleted (stale worktrees)
alias machine.usage.observe='machine_resource_observe'                       # system snapshot
alias machine.usage.snapshot='machine_usage_snapshot'                        # comprehensive lag diagnosis snapshot

# note: the 'terminal' command comes from `4.3.3.launcher` (supports 'terminal /path/to/dir')

# make it easier to open the file manager
alias files='nautilus & disown'

# show processes with highest swap usage
_report_usage_ram_swap() {
  local limit="${1:-20}"
  local total_kb=0

  # collect data
  local data
  data=$(
    for pid_dir in /proc/[0-9]*; do
      p="${pid_dir##*/}"
      val=$(awk '/VmSwap/{print $2}' "$pid_dir/status" 2>/dev/null)
      if [ -n "$val" ] && [ "$val" -gt 0 ]; then
        name=$(cat "$pid_dir/comm" 2>/dev/null)
        printf "%s\t%s\t%s\n" "$val" "$p" "$name"
      fi
    done | sort -rn | head -"$limit"
  )

  # count lines
  local count=0
  while IFS= read -r line; do
    [[ -n "$line" ]] && ((count++))
    total_kb=$((total_kb + $(echo "$line" | cut -f1)))
  done <<< "$data"

  local total_gb
  total_gb=$(echo "scale=1; $total_kb / 1048576" | bc)

  echo ""
  echo "🌊 ram.swap (top $limit)"
  echo "   ├─ total: ${total_gb}gb in top $limit"
  echo "   │"

  local i=0
  while IFS=$'\t' read -r kb pid name; do
    [[ -z "$kb" ]] && continue
    ((i++))
    local mb=$((kb / 1024))
    if [[ $i -eq $count ]]; then
      printf "   └─ %6dmb  %-20s (pid %s)\n" "$mb" "$name" "$pid"
    else
      printf "   ├─ %6dmb  %-20s (pid %s)\n" "$mb" "$name" "$pid"
    fi
  done <<< "$data"
  echo ""
}
alias report.usage.ram.swap='_report_usage_ram_swap'

# show processes with highest real memory (RSS) usage
_report_usage_ram_real() {
  local limit="${1:-20}"
  local total_kb=0

  # collect data
  local data
  data=$(
    for pid_dir in /proc/[0-9]*; do
      p="${pid_dir##*/}"
      val=$(awk '/VmRSS/{print $2}' "$pid_dir/status" 2>/dev/null)
      if [ -n "$val" ] && [ "$val" -gt 0 ]; then
        name=$(cat "$pid_dir/comm" 2>/dev/null)
        printf "%s\t%s\t%s\n" "$val" "$p" "$name"
      fi
    done | sort -rn | head -"$limit"
  )

  # count lines
  local count=0
  while IFS= read -r line; do
    [[ -n "$line" ]] && ((count++))
    total_kb=$((total_kb + $(echo "$line" | cut -f1)))
  done <<< "$data"

  local total_gb
  total_gb=$(echo "scale=1; $total_kb / 1048576" | bc)

  echo ""
  echo "🧠 ram.real (top $limit)"
  echo "   ├─ total: ${total_gb}gb in top $limit"
  echo "   │"

  local i=0
  while IFS=$'\t' read -r kb pid name; do
    [[ -z "$kb" ]] && continue
    ((i++))
    local mb=$((kb / 1024))
    if [[ $i -eq $count ]]; then
      printf "   └─ %6dmb  %-20s (pid %s)\n" "$mb" "$name" "$pid"
    else
      printf "   ├─ %6dmb  %-20s (pid %s)\n" "$mb" "$name" "$pid"
    fi
  done <<< "$data"
  echo ""
}
alias report.usage.ram.real='_report_usage_ram_real'
# make it easy to speed test internet connection (25MB download via Cloudflare)
_speedtest_internet() {
  setopt local_options no_notify no_monitor
  local total=25000000
  local width=30
  local tmp=$(mktemp)
  local tmpdata=$(mktemp)
  local start=$EPOCHREALTIME
  curl -o "$tmpdata" -w "%{speed_download}" -s "https://speed.cloudflare.com/__down?bytes=${total}" > "$tmp" &
  local pid=$!
  while kill -0 $pid 2>/dev/null; do
    local size=$(stat -c%s "$tmpdata" 2>/dev/null || echo 0)
    local elapsed=$(echo "$EPOCHREALTIME - $start" | bc)
    local speed=$(echo "scale=2; ($size * 8 / 1000000) / $elapsed" | bc 2>/dev/null || echo "0")
    local pct=$((size * 100 / total))
    local filled=$((size * width / total))
    local bar=$(printf '%*s' "$filled" '' | tr ' ' '#')$(printf '%*s' "$((width - filled))" '' | tr ' ' '-')
    printf "\r  [%s] %3d%% @ %6s mbps" "$bar" "$pct" "$speed"
    sleep 0.1
  done
  printf "\r  [%s] 100%%              \n" "$(printf '%*s' "$width" '' | tr ' ' '#')"
  local bytes_per_sec=$(cat "$tmp")
  rm "$tmp" "$tmpdata"
  local mbps=$(echo "scale=2; $bytes_per_sec * 8 / 1000000" | bc)
  local emoji
  if (( $(echo "$mbps < 5" | bc -l) )); then emoji="🐌"
  elif (( $(echo "$mbps < 30" | bc -l) )); then emoji="🦘"
  else emoji="🐆"
  fi
  echo "  speed.download = ${mbps} mbps ${emoji}"
}
alias speedtest.internet='_speedtest_internet'

# make it easy to speed test shell startup time
alias speedtest.shell.startup='ZPROF=1 zsh -i -c "zprof"'

# force rebuild zsh completions (use when tab completion missing for new tool)
alias compinit.rebuild='rm -f ~/.zcompdump* && autoload -Uz compinit && compinit && zcompile ~/.zcompdump'

# make it easy to change brightness beyond default brightness range; e.g., brightness 0.6
alias brightness='xrandr --output eDP-1 --brightness'

# make it easy to restart utils
alias restart.bluetooth='bluetoothctl power on && systemctl restart bluetooth'
alias restart.wifi='systemctl restart NetworkManager.service'

######################################################################
# grove.provision — raise this machine's state to the state the repo declares
#
#   grove.provision [--for cloud|local]          # every bundle this machine takes
#   grove.provision.<part> [--for cloud|local]   # one bundle
#   git.repo.pull && grove.provision          # the whole loop, direction explicit
#
# .why `provision`, not `install` and not `upgrade`
#   no machine is ever blank: every box already ships a shell, a PATH, and
#   /etc/skel dotfiles. so every run CONVERGES an extant tree — the first run
#   included — which `install` does not name.
#
#   `upgrade` names that convergence too, but it asserts a DIRECTION the act
#   does not have: pin an older starship in the repo and a converged machine
#   moves DOWN to meet it. `provision` asserts
#   no direction, and is the word `ahbode/infrastructure` already uses for what
#   it does to a box — so both halves of one lifecycle share one verb.
#   see .agent/.../domain.terms/term=grove.provision._.choice._.md
#
# .why ONE driver, and these are THIN WRAPPERS
#   every subpart below resolves to `grove.provision._.sh --what <slug>`. it holds
#   no list and no work of its own — delete any wrapper and the bundle still
#   runs, because the bundle lives in the tree.
#
#   this is enforced (rule.require.grove-provision-as-the-only-verb) because the
#   repo grew a duplicate driver THREE separate times, and each time the second
#   list drifted from the first. one of them had silently dropped `brains`, so
#   groves ran the robot brains with no config at all — the drift is quiet by
#   nature, which is why the rule is absolute rather than advisory.
#
# .why the machine is a FLAG, not a suffix
#   `grove.provision.<x>` names a PART of the tree (zshrc, nvim, tmux).
#   a machine is not a part, so a `.grove` suffix would put two orthogonal
#   dimensions in one namespace position. the machine axis is `--for`,
#   declared once in grove.for.sh and read by the one driver.
#
# .note every bundle lives under `src/grove.provision/`, and the directory tree
#   IS the inventory. there is no second list anywhere
#   (rule.require.bundle-as-sole-declaration).
#
#   the verb holds at the bundle level: a bundle's own `install_zsh` really does
#   run `apt install zsh`. it is the TREE as a whole, which always already
#   exists, that is provisioned rather than installed.
#
# .note the pair is split BY DIRECTION, and that split is the whole point:
#   `grove.provision.*` is repo → machine, `git.repo.pull.*` is remote → here.
#   one word for both leaves a reader unable to tell which way content moves
#   (`term=git.repo.pull._.choice._.md` carries the argument)
######################################################################

# .what: the tree src dir every upgrade copies from
# .why:  honors DEV_ENV_SETUP_DIR, so a worktree can raise the machine to ITS OWN configs
#        (e.g. DEV_ENV_SETUP_DIR=~/git/more/_worktrees/dev-env-setup.my-branch).
#        every phase reads this one accessor, so a worktree can never silently copy
#        the main checkout.
_grove_src() { echo "${DEV_ENV_SETUP_DIR:-$HOME/git/more/dev-env-setup}/src"; }

# .what = THE command. drives grove.provision._.sh, the root of the bundle tree
# .why  = one driver, one tree. every arg passes straight through, so `--for`,
#         `--what`, and `--mode` behave here exactly as they do there — there is
#         no second parser to drift. the DIRECTORY is the inventory, so there is
#         no list left to drift from
grove.provision() {
  local driver="$(_grove_src)/grove.provision._.sh"
  if [ ! -f "$driver" ]; then
    echo "✋ grove.provision: no driver at $driver" >&2
    echo "   what: grove.provision._.sh is the root of the bundle tree; without it" >&2
    echo "         there is no run" >&2
    echo "   fix:  git.repo.pull   # then retry" >&2
    return 2
  fi
  bash "$driver" "$@"
}

# .what = raise ONE named part of the tree
# .why   = a thin wrapper over `--what`. it names the TARGETS the part is made of
#          and holds no work itself — so a part can never drift from the driver.
#          the machine axis still applies: the driver defers a `local` step on a
#          `--for cloud` run, by its own tag, with no tag duplicated here
#
# ⚠️ .note = every target below is a SLUG, so this map is pure SYNONYM —
#          `grove.provision.starship` is a second name for
#          `grove.provision --what 2.6.starship`, and it holds no knowledge the
#          tree does not already carry (rule.require.bundle-as-sole-declaration).
#
#          it stays for the human's fingers: a short word is easier to type and
#          `grove.provision.<TAB>` completes. it is deliberately NOT grown — a new
#          concern is reached by its slug, never by a new line here:
#            grove.provision --what 2.3.ssh --mode apply
#
# ⚠️ .note = every value below is a SLUG, never a bare FUNCTION name. a map keyed
#          on a name in ANOTHER file rots when that file moves, and the rot is
#          invisible until a human types the part. a slug cannot rot the same
#          way — the driver enumerates the directories, so a slug that names no
#          bundle is caught by `--mode plan` rather than by a human at the
#          keyboard.
_grove_provision_part() {
  local part="$1"; shift
  local steps=""
  case "$part" in
    # a SLUG, so the whole bundle runs — every phase, in order. a provision
    # phase is idempotent (it skips at its pin), so a config refresh costs no
    # download
    bashaliases) steps="2.7.aliases" ;;
    zshrc)       steps="2.5.zsh" ;;
    starship)    steps="2.6.starship" ;;
    gitaliases)  steps="2.2.git" ;;
    tmux)        steps="2.8.tmux" ;;
    kitty)       steps="4.3.kitty" ;;
    nvim)        steps="4.5.nvim" ;;
    brains)      steps="5.3.brains" ;;
    terminal)    steps="4.3.3.launcher" ;;
    cosmic)      steps="3.2.theme" ;;
    *)
      echo "✋ grove.provision: no part named '$part'" >&2
      echo "   fix: one of — bashaliases zshrc starship gitaliases nvim tmux" >&2
      echo "                 brains kitty terminal cosmic" >&2
      echo "   or name a bundle slug directly, which needs no part at all:" >&2
      echo "     grove.provision --what 2.3.ssh --mode plan" >&2
      return 2 ;;
  esac

  local args=() s
  for s in $steps; do args+=(--what "$s"); done
  grove.provision "${args[@]}" "$@"
}

# one entrypoint per part, so `grove.provision.<TAB>` completes and a grep for a
# part name finds it. each is one line, because each holds no logic
grove.provision.bashaliases() { _grove_provision_part bashaliases "$@"; }
grove.provision.zshrc()       { _grove_provision_part zshrc       "$@"; }
grove.provision.starship()    { _grove_provision_part starship    "$@"; }
grove.provision.gitaliases()  { _grove_provision_part gitaliases  "$@"; }
grove.provision.nvim()        { _grove_provision_part nvim        "$@"; }
grove.provision.tmux()        { _grove_provision_part tmux        "$@"; }
grove.provision.brains()      { _grove_provision_part brains      "$@"; }
grove.provision.kitty()       { _grove_provision_part kitty       "$@"; }
grove.provision.terminal()    { _grove_provision_part terminal    "$@"; }
grove.provision.cosmic()      { _grove_provision_part cosmic      "$@"; }

# make it easy to pull down this repo
alias git.repo.pull='cd ~/git/more/dev-env-setup && git checkout main && git pull origin HEAD'

# snapshot every open kitty window (pwd, program, age, mem) and save it to
# ~/.kitty/snaps, so a session can be rebuilt later
#
# reads only /proc — never kitty remote control, never an env block
# see: .agent/repo=.this/role=any/briefs/creds/rule.require.security-paramount.md
# read a snap back with: .agent/…/briefs/desktop/term/howto.restore-kitty-session.md
#
# ⚠️ .why it names ~/.local/bin and not a checkout path
#    `4.3.4.snapshot` installs the snapper there from `src/machine/`, and the
#    low-battery guard calls the same path. one installed artifact, two callers
#    — so an upgrade moves both at once. a path into a canonical git clone ties
#    a shell alias to a repo that stays cloned at one spot
#    (`rule.require.bundles-own-their-dependencies`) and names a file outside
#    `src/`, the deployable unit — so a grove gets this alias and no snapper
#
# ⚠️ it is `bash <file>`, not the file directly. the exec bit is not carried by
#    every path a checkout arrives on (a zip, an archive, a noexec mount), and a
#    snap that fails on a mode bit loses exactly the map it exists to save
alias kitty.snap='bash ~/.local/bin/kitty.snap --save'

# make it easy to suspend and restart and shutdown
#
# .why power.off and power.restart snap FIRST
#      a deliberate reboot is the one power event we know of in advance, so it is
#      the cheapest place to save the window/pwd map. the unattended case — a
#      battery that runs out — is covered instead by the timer `4.3.4.snapshot`
#      installs. kitty.snap exits quietly where kitty is absent, so this stays
#      safe on any box
alias power.suspend='systemctl suspend' # todo, swap to `suspend-then-hibernate` when supported
alias power.off='kitty.snap; shutdown -h now'
alias power.restart='kitty.snap; reboot'

# make it easy to work with bluetooth devices
alias bluetooth.devices='bluetoothctl devices';
alias bluetooth.connect='bluetoothctl connect';
alias bluetooth.disconnect='bluetoothctl disconnect';

# make it easy to adjust brightness
alias keyboard.backlight.off='sudo tee /sys/class/leds/dell::kbd_backlight/brightness <<< 0'
alias keyboard.backlight.dim='sudo tee /sys/class/leds/dell::kbd_backlight/brightness <<< 1'
alias keyboard.backlight.bright='sudo tee /sys/class/leds/dell::kbd_backlight/brightness <<< 2'

# make it easy to fetch the weather
alias weather.in.here='curl wttr.in'
alias weather.in.indianapolis='curl wttr.in/Indianapolis'

# ahbode use.vpc.tunnel aliases
#
# ⚠️ $HOME, never a literal /home/<user>. an alias body is single-quoted, so the
#    expansion happens when the ALIAS RUNS, on whatever seat runs it. a hardcode
#    names one seat's home and is dead on the camper, whose $HOME is /home/camper
#    (`term=seat`). it is also weak dox in a PUBLIC repo
#    (`rule.forbid.dox-in-public-repo`) — one edit closes both.
alias use.ahbode.prep.vpc='use.ahbode.prep && "$HOME/.local/bin/use.vpc.tunnel"'
alias use.ahbode.prod.vpc='use.ahbode.prod && "$HOME/.local/bin/use.vpc.tunnel"'

# smart npm: use npm if package-lock.json exists, otherwise pnpm
npm() {
  if [[ -f "package-lock.json" ]]; then
    npm_real "$@"
  else
    pnpm "$@"
  fi
}

# smart npx: prefer local bin, then npx/pnpm exec based on lockfile
npx() {
  local cmd="$1"
  if [[ -n "$cmd" && -x "./node_modules/.bin/$cmd" ]]; then
    shift
    "./node_modules/.bin/$cmd" "$@"
  elif [[ -f "package-lock.json" ]]; then
    npx_real "$@"
  else
    pnpm exec "$@"
  fi
}

# tsx: run via smart npx (routes to npx or pnpm exec)
tsx() { npx tsx "$@"; }

# npm_real/npx_real for smart npm/npx wrappers (fnm setup is in .zshrc)
npm_real() { command npm "$@"; }
npx_real() { command npx "$@"; }

# cap nvim memory so no single editor core can hog the machine.
# .why = neovim 0.11+ runs the editor core as its own `nvim --embed`
#        process. a runaway plugin (treesitter/minimap/diff) can leak
#        it to multi-GB and thrash swap until the whole machine freezes.
#        a systemd user scope makes the kernel throttle it at MemoryHigh
#        and refuse to grow past MemoryMax, so it cannot hog the box.
#        the in-nvim self-watchdog (init.lua) trips first, below these
#        limits, to self-heal without a kill — this scope is the backstop.
nvim() {
  # find the real nvim binary, bypass this function (works in bash + zsh)
  local bin
  bin=$( unset -f nvim 2>/dev/null; command -v nvim )
  # cap only in a real user session with systemd; else run bare
  if [[ -n "$bin" ]] && command -v systemd-run >/dev/null 2>&1 && [[ -n "$XDG_RUNTIME_DIR" ]]; then
    systemd-run --user --scope --quiet --collect \
      -p MemoryHigh=1500M \
      -p MemoryMax=2G \
      "$bin" "$@"
  else
    command nvim "$@"
  fi
}

# cap claude memory so the fleet of sessions cannot hog the machine.
# .why = claude forks node subprocesses for tool calls (rhx, rhachet, jest).
#        those can orphan — their parent exits, systemd adopts them — yet
#        they stay in the session's cgroup. sessions left open for weeks
#        accrue hundreds, and dozens of sessions collectively exhaust ram.
# .how = every session joins a shared claude.slice. the aggregate cap lives
#        on the slice, so the kernel reclaims from the COLDEST sessions
#        first — idle week-old sessions get squeezed to swap while the
#        active one stays resident. per-session MemoryMax is only a runaway
#        backstop, deliberately far above normal peaks.
# .note = cgroup membership survives reparent to systemd, so this covers
#         orphaned node children too — that is why the scope, not the
#         process, is the right boundary.
# .size = measured peaks are 3.5-5.6G per session vs ~1G steady, because
#         context compaction and parallel tool calls spike hard. MemoryMax
#         must clear the peak or the cgroup oom killer reaps the session
#         mid-turn. 8G leaves headroom above the worst observed peak.
#         set the aggregate cap via: claude.memory.cap.set
claude() {
  # find the real claude binary, bypass this function (works in bash + zsh)
  local bin
  bin=$( unset -f claude 2>/dev/null; command -v claude )
  # cap only in a real user session with systemd; else run bare
  if [[ -n "$bin" ]] && command -v systemd-run >/dev/null 2>&1 && [[ -n "$XDG_RUNTIME_DIR" ]]; then
    systemd-run --user --scope --quiet --collect \
      --slice=claude.slice \
      -p MemoryMax=8G \
      "$bin" "$@"
  else
    command claude "$@"
  fi
}

# set the aggregate memory cap across ALL claude sessions.
# .why = per-session caps cannot stop N sessions from collectively eating
#        the box. this caps the fleet, and the kernel picks the victims by
#        coldness — which is what we want: idle sessions yield, active ones
#        keep their pages.
# .note = MemoryHigh throttles via reclaim; it never kills. safe to tighten
#         live — running sessions get squeezed down to the new line.
claude_memory_cap_set() {
  local cap="${1:-12G}"
  systemctl --user set-property claude.slice MemoryHigh="$cap"
  echo "🐢 claude.slice MemoryHigh=$cap (aggregate across all sessions)"
}
alias claude.memory.cap.set='claude_memory_cap_set'


######################
## support github app tokens auth
######################

# generates a short-lived github app installation access token (valid for 1 hour)
# usage: get_github_app_token <org> <app_id> <private_key>
get_github_app_token() {
  # prepare the jwt
  local ORG="$1" APP_ID="$2" PRIVATE_KEY="$3"
  local NOW=$(date +%s)
  local IAT=$((NOW - 60)) EXP=$((NOW + 600))
  local HEADER=$(echo -n '{"alg":"RS256","typ":"JWT"}' | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
  local PAYLOAD=$(echo -n "{\"iat\":${IAT},\"exp\":${EXP},\"iss\":\"${APP_ID}\"}" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
  local KEY_FILE=$(mktemp)
  echo -e "$PRIVATE_KEY" > "$KEY_FILE"
  local SIGNATURE=$(echo -n "${HEADER}.${PAYLOAD}" | openssl dgst -sha256 -sign "$KEY_FILE" 2>/dev/null | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
  rm -f "$KEY_FILE"
  if [[ -z "$SIGNATURE" ]]; then >&2 echo "error: failed to sign jwt (check private key format)"; return 1; fi

  # get the installation
  local JWT="${HEADER}.${PAYLOAD}.${SIGNATURE}"
  local INSTALLATION=$(curl -s -H "Authorization: Bearer $JWT" -H "Accept: application/vnd.github+json" "https://api.github.com/orgs/${ORG}/installation")
  local ERROR=$(echo "$INSTALLATION" | jq -r '.message // empty')
  if [[ -n "$ERROR" ]]; then >&2 echo "error: $ERROR"; return 1; fi

  # grab a token
  local INSTALLATION_ID=$(echo "$INSTALLATION" | jq '.id')
  local TOKEN_RESP=$(curl -s -X POST -H "Authorization: Bearer $JWT" -H "Accept: application/vnd.github+json" "https://api.github.com/app/installations/${INSTALLATION_ID}/access_tokens")
  local TOKEN=$(echo "$TOKEN_RESP" | jq -r '.token // empty')
  if [[ -z "$TOKEN" ]]; then >&2 echo "error: $(echo "$TOKEN_RESP" | jq -r '.message // "failed to get token"')"; return 1; fi

  # verify identity (output to stderr so it doesn't get captured in GITHUB_TOKEN=$(...) usage)
  local APP_SLUG=$(echo "$INSTALLATION" | jq -r '.app_slug')
  local REPOS=$(curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "https://api.github.com/installation/repositories" | jq -r '[.repositories[].name] | join(", ") // empty')
  >&2 echo ""
  >&2 echo "🔑 authentication succeeded"
  >&2 echo "├─ as: ${APP_SLUG}[bot]"
  >&2 echo "├─ org: ${ORG}"
  >&2 echo "└─ repos: ${REPOS:-all}"
  >&2 echo ""
  echo "$TOKEN"
}
alias use.github.declastruct.test='export GITHUB_TOKEN=$(get_github_app_token \
  ehmpathy \
  "$(op item get github.app.declastruct-test-auth --fields label=app_id --format json | jq -r .value)" \
  "$(op item get github.app.declastruct-test-auth --fields label=app_private_key --format json | jq -r .value)")'

######################
## git release helper (invoked by git alias.release)
##
## what: checks the status of release-please PRs and their CI checks
##
## why: release-please automates versioning + changelog, but you still need to
##      manually enable automerge. this command shows release status at a glance
##      and optionally enables automerge with --apply or reruns failed with --retry
##
## how:
##   git release this             # check current branch's PR; if on main, delegates to main
##   git release this --apply     # check PR + enable automerge
##   git release this --retry     # check PR + rerun failed workflows
##   git release this --findsert  # find or create PR for current branch (not main)
##   git release this --findsert --apply  # find/create PR + enable automerge
##   git release this --watch     # poll status every 5s until checks complete (5min timeout)
##   git release main             # check open release PR; if none, show latest tag status
##   git release main --apply     # check + enable automerge
##   git release main --retry     # check + rerun failed workflows
##   git release main --watch     # poll status every 5s until checks complete (5min timeout)
##
## output:
##   - shows version, CI status, and automerge state
##   - failed checks show the workflow name, url, and failing step
######################
git_alias_release() {
  local target="${1:-this}"
  local apply=false retry=false findsert=false watch=false
  [[ "$*" == *"--apply"* ]] && apply=true
  [[ "$*" == *"--retry"* ]] && retry=true
  [[ "$*" == *"--findsert"* ]] && findsert=true
  [[ "$*" == *"--watch"* ]] && watch=true

  echo "" # headspace
  if [ "$target" = "main" ]; then
    _git_release_main "$apply" "$retry" "$watch"
  else
    _git_release_this "$apply" "$retry" "$findsert" "$watch"
  fi

  # watch mode: poll until checks complete or timeout
  local watch_result=0
  if [ "$watch" = "true" ]; then
    _git_release_watch "$target" "$retry"
    watch_result=$?
  fi

  echo "" # headspace
  return $watch_result
}

# .what: report failed checks with links and optional retry
# .why:  shared logic for failure reporting across pr, tag, and watch modes
# .args:
#   $1 = prefix (indent string, e.g., "   │  " or "      ")
#   $2 = retry ("true" to trigger reruns)
#   $3 = source_type ("pr" for statusCheckRollup, "tag" for run list)
#   $4 = json_data (the raw JSON to extract failures from)
_git_release_report_failed_checks() {
  local prefix="$1" retry="$2" source_type="$3" json_data="$4"

  # extract failed checks based on source type
  local failed_checks=()
  if [ "$source_type" = "pr" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] && failed_checks+=("$line")
    done < <(echo "$json_data" | jq -r '.[] | select(.conclusion == "FAILURE") | [.name, (.detailsUrl // .targetUrl // ""), ""] | @tsv')
  else
    while IFS= read -r line; do
      [ -n "$line" ] && failed_checks+=("$line")
    done < <(echo "$json_data" | jq -r '.[] | select(.conclusion == "failure") | [.name, .url, (.databaseId | tostring)] | @tsv')
  fi

  local total_failed=${#failed_checks[@]}
  local idx=0
  for check in "${failed_checks[@]}"; do
    idx=$((idx + 1))
    local name url run_id
    name=$(echo "$check" | cut -f1)
    url=$(echo "$check" | cut -f2)
    run_id=$(echo "$check" | cut -f3)

    # determine if last item (affects tree structure)
    local is_last_item=false
    [ "$idx" -eq "$total_failed" ] && [ "$retry" = "true" ] && is_last_item=true

    # set detail prefix based on whether more siblings follow
    local detail_prefix="${prefix}│"
    if [ "$is_last_item" = "true" ]; then
      echo "${prefix}└─ 🔴 $name"
      detail_prefix="${prefix} "
    else
      echo "${prefix}├─ 🔴 $name"
    fi

    # extract run_id from url if not provided directly (PR case)
    if [ -z "$run_id" ] && [ -n "$url" ]; then
      run_id=$(echo "$url" | sed -n 's/.*actions\/runs\/\([0-9]*\).*/\1/p')
    fi

    # get failure details and optionally retry
    if [ -n "$run_id" ]; then
      local err
      err=$(gh run view "$run_id" --json jobs -q '.jobs[] | select(.conclusion == "failure") | (.steps[] | select(.conclusion == "failure") | .name) // .name' | head -1)
      echo "${detail_prefix}     ├─ $url"
      if [ "$retry" = "true" ]; then
        echo "${detail_prefix}     ├─ ${err:-(see logs)}"
        gh run rerun "$run_id" --failed
        echo "${detail_prefix}     └─ 👌 rerun triggered"
      else
        echo "${detail_prefix}     └─ ${err:-(see logs)}"
      fi
    else
      echo "${detail_prefix}     └─ $url"
    fi
  done

  # show hint if not retrying
  if [ "$retry" != "true" ]; then
    echo -e "${prefix}└─ \033[2mhint: use --retry to rerun failed workflows\033[0m"
  fi
}

# .what: execute gh command with retry on transient network errors
# .why:  api calls can fail due to TLS timeouts, connection resets, etc
_gh_with_retry() {
  local max_retries=3
  local retry_delay=5
  local attempt=1
  local output exit_code

  while [ "$attempt" -le "$max_retries" ]; do
    # capture both stdout and stderr, track exit code
    output=$("$@" 2>&1)
    exit_code=$?

    # check for transient network errors in output
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qiE "(TLS handshake timeout|connection reset|network|timeout|ETIMEDOUT|ECONNRESET)"; then
      if [ "$attempt" -lt "$max_retries" ]; then
        sleep "$retry_delay"
        attempt=$((attempt + 1))
        continue
      fi
      # max retries exceeded
      return 1
    fi

    # success
    echo "$output"
    return 0
  done
}

# .what: poll until checks complete or timeout (5min)
# .why:  monitor CI progress without manual re-running
_git_release_watch() {
  local target="$1" retry="$2"
  local start_time action_started_epoch
  start_time=$(date +%s)

  echo "   └─ 🥥 let's watch"

  while true; do
    # check if there are still pending checks
    local pending=0 pr_num tag_latest
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)
    local is_main=false
    [ "$target" = "main" ] || [ "$current_branch" = "main" ] || [ "$current_branch" = "master" ] && is_main=true

    if [ "$is_main" = "true" ]; then
      local pr_list_result
      pr_list_result=$(_gh_with_retry gh pr list --state open --json number,title) || {
        echo "      └─ ⛈️  gh api failed after retries"
        return 1
      }
      pr_num=$(echo "$pr_list_result" | jq -r '.[] | select(.title | test("chore\\(release\\)")) | .number' | head -1)
      # if no release PR, watch latest tag runs instead
      if [ -z "$pr_num" ]; then
        git fetch origin --tags -q 2>/dev/null
        tag_latest=$(git tag --sort=-v:refname | head -1)
      fi
    elif [ -n "$current_branch" ]; then
      local pr_list_result
      pr_list_result=$(_gh_with_retry gh pr list --head "$current_branch" --state open --json number --limit 1) || {
        echo "      └─ ⛈️  gh api failed after retries"
        return 1
      }
      pr_num=$(echo "$pr_list_result" | jq -r '.[0].number // empty')
    fi

    if [ -n "$pr_num" ]; then
      local check_data
      check_data=$(_gh_with_retry gh pr view "$pr_num" --json statusCheckRollup -q '.statusCheckRollup') || {
        echo "      └─ ⛈️  gh api failed after retries"
        return 1
      }
      pending=$(echo "$check_data" | jq '[.[] | select(.status != "COMPLETED")] | length')
      # capture oldest start time across ALL checks on first iteration
      if [ -z "$action_started_epoch" ]; then
        local oldest_started
        oldest_started=$(echo "$check_data" | jq -r '[.[].startedAt // empty] | map(select(. != null)) | sort | first // empty')
        [ -n "$oldest_started" ] && action_started_epoch=$(date -d "$oldest_started" +%s 2>/dev/null)
      fi
    elif [ -n "$tag_latest" ]; then
      local tag_runs
      tag_runs=$(_gh_with_retry gh run list --branch "$tag_latest" --json status,createdAt --limit 10) || {
        echo "      └─ ⛈️  gh api failed after retries"
        return 1
      }
      pending=$(echo "$tag_runs" | jq '[.[] | select(.status != "completed")] | length')
      # capture oldest start time across ALL runs on first iteration
      if [ -z "$action_started_epoch" ]; then
        local oldest_started
        oldest_started=$(echo "$tag_runs" | jq -r '[.[].createdAt] | sort | first // empty')
        [ -n "$oldest_started" ] && action_started_epoch=$(date -d "$oldest_started" +%s 2>/dev/null)
      fi
    fi

    # calc elapsed times
    local watch_elapsed=$(( $(date +%s) - start_time ))
    local watch_mins=$((watch_elapsed / 60))
    local watch_secs=$((watch_elapsed % 60))
    local watch_str="${watch_secs}s"
    [ "$watch_mins" -gt 0 ] && watch_str="${watch_mins}m${watch_secs}s"

    local action_str=""
    if [ -n "$action_started_epoch" ]; then
      local action_elapsed=$(( $(date +%s) - action_started_epoch ))
      local action_mins=$((action_elapsed / 60))
      local action_secs=$((action_elapsed % 60))
      action_str="${action_secs}s"
      [ "$action_mins" -gt 0 ] && action_str="${action_mins}m${action_secs}s"
    fi

    # check for failures early - exit as soon as any check fails
    local failed=0
    if [ -n "$pr_num" ]; then
      failed=$(echo "$check_data" | jq '[.[] | select(.conclusion == "FAILURE")] | length')
    elif [ -n "$tag_latest" ]; then
      failed=$(echo "$tag_runs" | jq '[.[] | select(.conclusion == "failure")] | length')
    fi

    if [ "$failed" -gt 0 ]; then
      if [ -n "$action_str" ]; then
        echo "      └─ ⛈️  $failed failure(s) detected! ${action_str} in action, ${watch_str} watched"
      else
        echo "      └─ ⛈️  $failed failure(s) detected! ${watch_str} watched"
      fi
      if [ -n "$pr_num" ]; then
        _git_release_report_failed_checks "         " "$retry" "pr" "$check_data"
      else
        _git_release_report_failed_checks "         " "$retry" "tag" "$tag_runs"
      fi
      return 1
    fi

    # exit if all checks complete
    if [ "$pending" -eq 0 ]; then
      if [ -n "$action_str" ]; then
        echo "      └─ ✨ done! ${action_str} in action, ${watch_str} watched"
      else
        echo "      └─ ✨ done! ${watch_str} watched"
      fi
      return 0
    fi

    # emit status
    if [ -n "$action_str" ]; then
      echo "      ├─ 💤 ${pending} left, ${action_str} in action, ${watch_str} watched"
    else
      echo "      ├─ 💤 ${pending} left, ${watch_str} watched"
    fi

    # timeout after 5 minutes (300 seconds)
    if [ "$watch_elapsed" -ge 300 ]; then
      echo "      └─ 🌙 watch timeout"
      return 1
    fi

    # sleep 5s for first 60s, then 15s afterwards
    if [ "$watch_elapsed" -lt 60 ]; then
      sleep 5
    else
      sleep 15
    fi
  done
}

# .what: check current branch's PR; if on main, delegate to _git_release_main
# .why:  convenient way to check PR status from any feature branch
_git_release_this() {
  local apply="$1" retry="$2" findsert="$3" watch="$4"
  local current_branch
  current_branch=$(git branch --show-current 2>/dev/null)

  # if on main/master, delegate to release main
  if [ "$current_branch" = "main" ] || [ "$current_branch" = "master" ] || [ -z "$current_branch" ]; then
    _git_release_main "$apply" "$retry" "$watch"
    return
  fi

  # find PR for current branch (open first, then merged)
  local pr_num
  pr_num=$(gh pr list --head "$current_branch" --state open --json number --limit 1 | jq -r '.[0].number // empty')

  if [ -z "$pr_num" ]; then
    # check for merged PR
    pr_num=$(gh pr list --head "$current_branch" --state merged --json number --limit 1 | jq -r '.[0].number // empty')
  fi

  if [ -z "$pr_num" ]; then
    echo "🫧  no open branch pr"
    echo "   ├─ $current_branch"
    # check for unpushed commits
    local unpushed
    unpushed=$(git log --oneline "@{u}..HEAD" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$unpushed" -gt 0 ] 2>/dev/null; then
      echo "   ├─ $unpushed unpushed commit(s)"
    fi
    if [ "$findsert" = "true" ]; then
      echo "   └─ 🌴 creating pr..."
      gh pr create --fill
      echo ""
      # re-fetch the newly created PR and continue to show status / apply automerge
      pr_num=$(gh pr list --head "$current_branch" --state open --json number --limit 1 | jq -r '.[0].number // empty')
      if [ -n "$pr_num" ]; then
        _git_release_pr "$pr_num" "$apply" "$retry" "$watch"
      fi
    else
      echo -e "   ├─ \033[2mtry 'git release --findsert' to find or create pr\033[0m"
      echo -e "   └─ \033[2mtry 'git release main' to see latest release\033[0m"
    fi
    return 0
  fi

  _git_release_pr "$pr_num" "$apply" "$retry" "$watch"
}

# .what: check open release PR; if none, show latest tag status
# .why:  see status of pending release or last completed release
_git_release_main() {
  local apply="$1" retry="$2" watch="$3"
  local pr_num
  pr_num=$(gh pr list --state open --json number,title | jq -r '.[] | select(.title | test("chore\\(release\\)")) | .number' | head -1)

  if [ -z "$pr_num" ]; then
    echo "🫧  no open release pr"
    git fetch origin --tags -q 2>/dev/null
    local tag_latest
    tag_latest=$(git tag --sort=-v:refname | head -1)

    if [ -n "$tag_latest" ]; then
      echo ""
      _git_release_tag_runs "$tag_latest" "$retry"
    fi
    return 0
  fi

  _git_release_pr "$pr_num" "$apply" "$retry" "$watch"
}

# .what: check a specific PR's CI status and automerge state
# .why:  unified logic for displaying PR status, regardless of open/merged state
_git_release_pr() {
  local pr_num="$1" apply="$2" retry="$3" watch="$4"
  local pr
  pr=$(gh pr view "$pr_num" --json number,title,state,statusCheckRollup,autoMergeRequest,mergeStateStatus)

  local title state automerge failed pending version merge_state
  title=$(echo "$pr" | jq -r '.title')
  state=$(echo "$pr" | jq -r '.state')
  automerge=$(echo "$pr" | jq -r '.autoMergeRequest')
  merge_state=$(echo "$pr" | jq -r '.mergeStateStatus')
  failed=$(echo "$pr" | jq -r '[.statusCheckRollup[] | select(.conclusion == "FAILURE")] | length')
  pending=$(echo "$pr" | jq -r '[.statusCheckRollup[] | select(.status != "COMPLETED")] | length')
  version=$(echo "$title" | sed -n 's/.*\(v[0-9][0-9.]*\).*/\1/p')

  # determine if this is the final line (merged PRs don't show automerge)
  local is_merged=false
  [ "$state" = "MERGED" ] && is_merged=true

  echo "🌊 release: ${version:-$title}"

  # show check status
  local check_data
  check_data=$(echo "$pr" | jq -r '.statusCheckRollup')
  if [ "$failed" -gt 0 ]; then
    echo "   ├─ ⛈️  $failed check(s) failed"
    # show in-progress checks first
    if [ "$pending" -gt 0 ]; then
      echo "   │  ├─ 🟡 $pending check(s) still in progress"
    fi
    _git_release_report_failed_checks "   │  " "$retry" "pr" "$check_data"
  elif [ "$pending" -gt 0 ]; then
    echo "   ├─ 🐢 $pending check(s) in progress"
  else
    echo "   ├─ 👌 all checks passed"
  fi

  # warn if branch is behind base or has conflicts
  if [ "$merge_state" = "BEHIND" ] && [ "$is_merged" != "true" ]; then
    echo "   ├─ 🐚 needs rebase" # shell: left behind on shore while the wave moves on
  elif [ "$merge_state" = "DIRTY" ] && [ "$is_merged" != "true" ]; then
    echo "   ├─ 🐚 needs rebase, has conflicts"
  fi

  # show automerge status (use ├─ if watch mode will add more, else └─)
  local prefix="└─"
  [ "$watch" = "true" ] && prefix="├─"

  if [ "$is_merged" = "true" ]; then
    echo "   └─ 🌴 already merged"
  elif [ "$automerge" = "null" ]; then
    if [ "$apply" = "true" ]; then
      gh pr merge "$pr_num" --auto --squash > /dev/null
      # check if PR was merged immediately (all checks passed + no branch protection delay)
      local post_state
      post_state=$(gh pr view "$pr_num" --json state -q '.state')
      if [ "$post_state" = "MERGED" ]; then
        echo "   └─ 🌴 automerge enabled [added] -> already merged"
      else
        echo "   $prefix 🌴 automerge enabled [added]"
      fi
    else
      echo "   $prefix 🌴 automerge unfound (use --apply to add)"
    fi
  else
    echo "   $prefix 🌴 automerge enabled [found]"
  fi
}

# .what: check a specific tag's workflow runs directly
# .why:  fallback when no merged PR is found for a tag (e.g., manual releases)
_git_release_tag_runs() {
  local tag="$1" retry="$2"

  echo "🌊 release: $tag"
  local tag_runs tag_failed tag_pending
  tag_runs=$(gh run list --branch "$tag" --json name,conclusion,status,url,databaseId --limit 5)
  tag_failed=$(echo "$tag_runs" | jq -r '[.[] | select(.conclusion == "failure")] | length')
  tag_pending=$(echo "$tag_runs" | jq -r '[.[] | select(.status != "completed")] | length')

  if [ "$tag_failed" -gt 0 ]; then
    echo "   └─ ⛈️  $tag_failed check(s) failed"
    # show in-progress checks first
    if [ "$tag_pending" -gt 0 ]; then
      echo "      ├─ 🟡 $tag_pending check(s) still in progress"
    fi
    _git_release_report_failed_checks "      " "$retry" "tag" "$tag_runs"
  elif [ "$tag_pending" -gt 0 ]; then
    echo "   └─ 🐢 $tag_pending check(s) in progress"
  else
    echo "   └─ 👌 all checks passed"
  fi
}

######################
## git tree (invoked by git alias.tree)
##
## what: manage git worktrees with repo-prefixed directory names
##
## why: enables parallel work on branches without stashing/switching
##      repo prefix prevents collisions when working across multiple repos
##
## how:
##   git tree get                            # list worktrees for current repo
##   git tree set <branch> --from main|tree  # create/find worktree for branch
##   git tree del <branch>                   # remove worktree for branch
##   git tree del --repo <name> --name <b>   # remove worktree by repo/branch
##   git tree status                         # show worktree status for current repo
##   git tree status --repo @all             # show worktree status across all repos
##
## worktree location: @gitroot/../_worktrees/$reponame.$branch/
##
## status demo:
##   🏔️  my-repo
##      │
##      ├─ 🌲 feat/yubikey-setup
##      │     └─ 👌 merged
##      │
##      ├─ 🌲 fix/typo
##      │     ├─ ✋ unpushed (2)
##      │     └─ 🌱 fix(readme): correct typo
##      │
##      ├─ 🌲 vlad/wip-idea
##      │     ├─ ✋ unstaged, unmerged pr
##      │     └─ 🌱 wip(auth): explore new approach
##      │
##      └─ 🌲 vlad/fresh
##            └─ 🫧 no work
######################

# .what: get the repo name from git root
_git_tree_repo_name() {
  local git_root
  git_root="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [[ "$git_root" == *"_worktrees"* ]]; then
    # inside a worktree: extract repo name from path (e.g., reponame.branch)
    basename "$git_root" | cut -d. -f1
  else
    basename "$git_root"
  fi
}

######################################################################
# _git_commit_line — one commit's `<abbrev> <subject>`, SAFE for a terminal
#
# .what = the `git log -1 --format='%h %s'` seven call sites need, routed
#         through `__duct_strip_escapes` — one holder, never seven.
#
# 🛑 .why — a commit SUBJECT is text a remote chose
#      a subject is author-controlled bytes carried by `git fetch`, and every
#      caller below prints it to a terminal with a bare `echo`. so a commit
#      whose subject holds `\e]52;c;<b64>\a` WRITES THIS HUMAN'S CLIPBOARD when
#      they run `git tree list` — with `set-clipboard on` in `src/tmux.conf`,
#      the next paste is a command that commit chose.
#
#      ⇒ and the tree is REACHABLE with no extra step: `git.grove.pull` writes a
#        tree the GROVE named, and a grove is ASSUMED COMPROMISED. `git tree
#        list` then walks every worktree it finds.
#
# ⚠️ .STRIPPED AT CAPTURE, never at echo — and the count is the reason
#      8 capture sites feed 14 echo sites. a guard at the echo is 14 places to
#      be right and a 15th `echo` away from being wrong; a guard at the capture
#      is one, and a new echo beside it inherits it (`term=holder`).
#
# ⚠️ .the SINK, never a parameter expansion — MEASURED 2026-08-31
#      `${x//[[:cntrl:]]/}` looks cheaper and is wrong HERE, because this file
#      is sourced by BOTH shells and they disagree on it. one payload, one
#      locale, `x\a\e]52;c;ZXZpbA==\a\177\302\233Y\233Z`:
#
#        bash 5.2  ALL → left `c2 9b` AND bare `9b`
#        zsh  5.9  ALL → left bare `9b`   (it cut the encoded `c2 9b`)
#
#      so `[[:cntrl:]]` reaches neither spelling of C1 in bash, and only the
#      encoded one in zsh. `__duct_strip_escapes` is `tr`/`iconv`/`sed` —
#      external programs — so it answers the same in both.
#
#      ⚠️ and ONE slash is not ALL: `${x/[[:cntrl:]]/}` cut the first BEL and
#         left `1b 07 7f c2 9b 9b` standing, in BOTH shells.
#
# ⚠️ .the BOUND this states rather than hides
#      the sink KEEPS tab and newline on purpose, so a subject with a tab still
#      shifts a column. that is cosmetic — a tab drives no terminal action —
#      and the alternative eats every table this sink also relays.
#
# ⚠️ .an absent sink fails CLOSED, and loudly
#      `~/.bash_aliases.ductwork.sh` is sourced under a `[[ -f ]]` guard at the
#      top of this file. where it is absent the pipeline below writes
#      `command not found` to stderr and yields an empty string, so this returns
#      `(unknown)` — never the raw bytes (`rule.forbid.failhide`).
#
# ✔ .SEEN TO DISCRIMINATE, 2026-08-31 — on a REAL commit, both directions
#      a temp repo took one commit whose SUBJECT is
#      `fix: a wave` + BEL + OSC 52 + BEL + DEL + C1 + ` done`, and both readers
#      were run over it — this function extracted from this file verbatim, and
#      the sink from the INSTALLED `~/.bash_aliases.ductwork.sh`:
#
#        RAW  …61 20 77 61 76 65 07 1b 5d 35 32 … 07 7f c2 9b 58 c2 9b 59 20 64…
#        NEW  …61 20 77 61 76 65 5d 35 32 … 58 59 20 64 6f 6e 65
#
#      cut: `1b` `07` `7f` `9b`. kept: `fix: a wave` and `done`, on both sides
#      of the payload — so the OSC 52 survives as inert text and drives no
#      terminal.
#
#      ⚠️ the LAST two rows are what make the first five mean anything. a sink
#         that returns an empty string cuts every escape and is useless, so this
#         asserts the words survived and that the `(unknown)` path did not fire
#         (`gotcha.a-check-that-cries-wolf-gets-silenced`, `.the corollary`).
#
#      ⚠️ and the FIRST row is the other guard: it asserts the RAW reader still
#         carries `1b` and `07`. git normalizes a subject on commit, so a
#         fixture git had quietly cleaned would prove a repair that repaired no
#         defect. (it does not: git kept both, and re-spelled the bare `\233`
#         as `c2 9b`.)
#
# args: <dir> [<rev>]
######################################################################
_git_commit_line() {
  local dir="$1" rev="${2:-HEAD}" line
  # ⚠️ ONE LINE on purpose. `2.7.aliases`'s configure.verify counts subject
  #    captures that do NOT name the sink and demands ZERO — a rule with no
  #    magic constant, which a continuation would break
  line="$(git -C "$dir" log -1 --format='%h %s' "$rev" 2>/dev/null | __duct_strip_escapes)"
  [[ -n "$line" ]] || line="(unknown)"
  printf '%s' "$line"
}

# .what: sanitize branch name for filesystem (/ -> .)
_git_tree_sanitize_branch() {
  echo "$1" | tr '/' '.'
}

# .what: resolve the _worktrees directory path
_git_tree_worktrees_dir() {
  local git_root
  git_root="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [[ "$git_root" == *"_worktrees"* ]]; then
    # inside a worktree: parent is the _worktrees dir
    dirname "$git_root"
  else
    # in main repo: sibling _worktrees dir
    echo "$(dirname "$git_root")/_worktrees"
  fi
}

# .what: main dispatcher for git tree commands
git_alias_tree() {
  local cmd="${1:-get}"
  shift 2>/dev/null || true

  case "$cmd" in
    -h|--help)
      echo "git tree - manage worktrees with repo-prefixed directories"
      echo ""
      echo "usage: git tree <command> [options]"
      echo ""
      echo "commands:"
      echo "  get          list worktrees for current repo"
      echo "  set <branch> create or find worktree for branch"
      echo "  del <branch> remove worktree for branch"
      echo "  status       show worktree status (deletable, dirty, etc)"
      echo ""
      echo "run 'git tree <command> --help' for command-specific options"
      return 0
      ;;
    get) _git_tree_get "$@" ;;
    set) _git_tree_set "$@" ;;
    del) _git_tree_del "$@" ;;
    status) _git_tree_status "$@" ;;
    *)
      echo "usage: git tree <get|set|del|status> [branch]"
      echo "run 'git tree --help' for more info"
      return 1
      ;;
  esac
}

# .what: list worktrees for current repo, or open a specific one
_git_tree_get() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "git tree get - list worktrees for current repo or all repos"
    echo ""
    echo "usage: git tree get [branch] [--repo <name|@all>] [--open <opener>]"
    echo ""
    echo "options:"
    echo "  <branch>            show specific worktree (optional)"
    echo "  --repo <name|@all>  filter by repo name or show all repos"
    echo "  --open <opener>     open worktree with specified opener"
    echo "                      e.g., --open terminal, --open codium"
    echo ""
    echo "examples:"
    echo "  git tree get                        # list all worktrees for current repo"
    echo "  git tree get --repo @all            # list all worktrees across all repos"
    echo "  git tree get feat/foo               # show specific worktree"
    echo "  git tree get feat/foo --open codium # open in codium"
    return 0
  fi

  local branch="" opener="" repo_filter=""

  # parse args
  local prev=""
  for arg in "$@"; do
    if [[ "$prev" == "--open" ]]; then
      opener="$arg"
      prev=""
      continue
    fi
    if [[ "$prev" == "--repo" ]]; then
      repo_filter="$arg"
      prev=""
      continue
    fi
    case "$arg" in
      --open) prev="--open" ;;
      --repo) prev="--repo" ;;
      -*) ;;
      *) [[ -z "$branch" ]] && branch="$arg" ;;
    esac
  done

  # fail fast if --open without opener
  if [[ "$prev" == "--open" ]]; then
    echo "error: --open requires an opener (e.g., --open terminal, --open codium)"
    return 1
  fi

  local worktrees_dir repo_name
  worktrees_dir="$(_git_tree_worktrees_dir)"
  repo_name="$(_git_tree_repo_name)"

  # if branch specified, find and optionally open it
  if [[ -n "$branch" ]]; then
    local sanitized worktree_path
    sanitized="$(_git_tree_sanitize_branch "$branch")"
    worktree_path="$worktrees_dir/$repo_name.$sanitized"

    if [[ ! -d "$worktree_path" ]]; then
      echo "🍃 worktree for '$branch' not found"
      echo -e "   └─ \033[2mtry 'git tree set $branch --from main|tree' to create it\033[0m"
      return 1
    fi

    local commit_info created_epoch mtime_epoch created_fmt mtime_fmt relative
    commit_info=$(_git_commit_line "$worktree_path")
    created_epoch=$(stat -c %W "$worktree_path" 2>/dev/null || echo "0")
    mtime_epoch=$(stat -c %Y "$worktree_path" 2>/dev/null || echo "0")
    [[ "$created_epoch" == "0" ]] && created_epoch="$mtime_epoch"
    created_fmt=$(_git_tree_format_date "$created_epoch")
    mtime_fmt=$(_git_tree_format_date "$mtime_epoch")
    relative=$(_git_tree_relative_time "$mtime_epoch")

    echo ""
    echo "🌲 $repo_name.$sanitized"
    echo "   ├─ branch: $branch"
    echo -e "   ├─ \033[2mat $worktree_path\033[0m"
    echo -e "   ├─ \033[2mon $created_fmt → $mtime_fmt, $relative\033[0m"
    if [[ -n "$opener" ]]; then
      echo "   ├─ $commit_info"
      echo -e "   └─ \033[2mopen in $opener...\033[0m"
    else
      echo "   └─ $commit_info"
    fi
    echo ""

    # note: subshell ensures opener inherits correct cwd, without mutate of parent shell
    if [[ -n "$opener" ]]; then
      (cd "$worktree_path" && "$opener" .) &
    fi
    return 0
  fi

  # handle --repo flag for multi-repo mode
  if [[ -n "$repo_filter" ]]; then
    local found_any=false repos=() rname
    local worktrees_base="${worktrees_dir%/*}"

    # ⚠️ every walk below is `find`-fed, never a bare glob. this file is read
    #    by zsh, where a glob that matches no file aborts the whole function —
    #    and a `_worktrees` dir that holds no worktree is the NORMAL state of a
    #    fresh box, not an edge case
    #    (`rule.forbid.bare-globs-in-dual-shell-files`)
    while IFS= read -r worktrees_dir; do
      [[ -d "$worktrees_dir" ]] || continue
      while IFS= read -r dir; do
        [[ -d "$dir" ]] || continue
        [[ "$(basename "$dir")" == "_patches" ]] && continue
        rname=$(basename "$dir" | cut -d. -f1)
        if [[ "$repo_filter" != "@all" && "$rname" != "$repo_filter" ]]; then
          continue
        fi
        if [[ ! " ${repos[*]} " =~ " ${rname} " ]]; then
          repos+=("$rname")
        fi
      done < <(find "$worktrees_dir" -mindepth 1 -maxdepth 1 2>/dev/null | sort)

      for repo_name in "${repos[@]}"; do
        local entries=()
        while IFS= read -r dir; do
          [[ -d "$dir" ]] || continue
          local timestamp
          timestamp=$(stat -c %Y "$dir" 2>/dev/null || echo "0")
          entries+=("$timestamp:$dir")
        done < <(find "$worktrees_dir" -mindepth 1 -maxdepth 1 -name "$repo_name".'*' 2>/dev/null | sort)

        [[ ${#entries[@]} -eq 0 ]] && continue

        found_any=true

        # sort by timestamp (most recent first)
        local sorted
        IFS=$'\n' sorted=($(printf '%s\n' "${entries[@]}" | sort -t: -k1 -rn)); unset IFS

        echo ""
        echo "🏔️  $repo_name"
        echo "   │"

        local idx=0 total=${#sorted[@]}
        for entry in "${sorted[@]}"; do
          ((idx++))
          local timestamp dir name branch_name commit_info
          local created_epoch mtime_epoch created_fmt mtime_fmt relative
          timestamp="${entry%%:*}"
          dir="${entry#*:}"
          name="$(basename "$dir")"
          branch_name="${name#$repo_name.}"
          commit_info=$(_git_commit_line "$dir")
          created_epoch=$(stat -c %W "$dir" 2>/dev/null || echo "0")
          mtime_epoch="$timestamp"
          [[ "$created_epoch" == "0" ]] && created_epoch="$mtime_epoch"
          created_fmt=$(_git_tree_format_date "$created_epoch")
          mtime_fmt=$(_git_tree_format_date "$mtime_epoch")
          relative=$(_git_tree_relative_time "$mtime_epoch")

          if [[ $idx -eq $total ]]; then
            echo "   └─ 🌲 $branch_name"
            echo -e "       ├─ \033[2mat $dir\033[0m"
            echo -e "       ├─ \033[2mon $created_fmt → $mtime_fmt, $relative\033[0m"
            echo "       └─ $commit_info"
          else
            echo "   ├─ 🌲 $branch_name"
            echo -e "   │     ├─ \033[2mat $dir\033[0m"
            echo -e "   │     ├─ \033[2mon $created_fmt → $mtime_fmt, $relative\033[0m"
            echo "   │     └─ $commit_info"
            echo "   │"
          fi
        done
      done
      repos=()
    done < <(find "$worktrees_base" -mindepth 2 -maxdepth 2 -type d -name '_worktrees' 2>/dev/null | sort)

    if [[ "$found_any" == "false" ]]; then
      echo ""
      if [[ "$repo_filter" == "@all" ]]; then
        echo "🏔️  (no worktrees on machine)"
      else
        echo "🏔️  $repo_filter"
        echo "   └─ (no worktrees)"
      fi
    fi

    echo ""
    return 0
  fi

  # no branch specified, no --repo: list all worktrees for current repo
  if [[ ! -d "$worktrees_dir" ]]; then
    echo ""
    echo "🏔️  $repo_name"
    echo "   └─ (no worktrees)"
    echo ""
    return 0
  fi

  local entries=()
  # ⚠️ `find`, not a bare glob — zsh aborts the function on a no-match glob,
  #    and a repo with zero worktrees is the common case the block below is
  #    written to report (`rule.forbid.bare-globs-in-dual-shell-files`)
  while IFS= read -r dir; do
    [[ -d "$dir" ]] || continue
    local timestamp
    timestamp=$(stat -c %Y "$dir" 2>/dev/null || echo "0")
    entries+=("$timestamp:$dir")
  done < <(find "$worktrees_dir" -mindepth 1 -maxdepth 1 -name "$repo_name".'*' 2>/dev/null | sort)

  if [[ ${#entries[@]} -eq 0 ]]; then
    echo ""
    echo "🏔️  $repo_name"
    echo "   └─ (no worktrees)"
    echo ""
    return 0
  fi

  # sort by timestamp (most recent first)
  local sorted
  IFS=$'\n' sorted=($(printf '%s\n' "${entries[@]}" | sort -t: -k1 -rn)); unset IFS

  echo ""
  echo "🏔️  $repo_name"
  echo "   │"

  local idx=0 total=${#sorted[@]}
  for entry in "${sorted[@]}"; do
    ((idx++))
    local timestamp dir name branch_name commit_info
    local created_epoch mtime_epoch created_fmt mtime_fmt relative
    timestamp="${entry%%:*}"
    dir="${entry#*:}"
    name="$(basename "$dir")"
    branch_name="${name#$repo_name.}"
    commit_info=$(_git_commit_line "$dir")
    created_epoch=$(stat -c %W "$dir" 2>/dev/null || echo "0")
    mtime_epoch="$timestamp"
    [[ "$created_epoch" == "0" ]] && created_epoch="$mtime_epoch"
    created_fmt=$(_git_tree_format_date "$created_epoch")
    mtime_fmt=$(_git_tree_format_date "$mtime_epoch")
    relative=$(_git_tree_relative_time "$mtime_epoch")

    if [[ $idx -eq $total ]]; then
      echo "   └─ 🌲 $branch_name"
      echo -e "       ├─ \033[2mat $dir\033[0m"
      echo -e "       ├─ \033[2mon $created_fmt → $mtime_fmt, $relative\033[0m"
      echo "       └─ $commit_info"
    else
      echo "   ├─ 🌲 $branch_name"
      echo -e "   │     ├─ \033[2mat $dir\033[0m"
      echo -e "   │     ├─ \033[2mon $created_fmt → $mtime_fmt, $relative\033[0m"
      echo "   │     └─ $commit_info"
      echo "   │"
    fi
  done
  echo ""
}

# .what: create or find worktree for branch
_git_tree_set() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "git tree set - create or find worktree for branch"
    echo ""
    echo "usage: git tree set <branch> --from <main|tree> [options]"
    echo ""
    echo "options:"
    echo "  --from main         create branch from origin/main"
    echo "  --from tree         create branch from this tree's HEAD"
    echo "  --open <opener>     open worktree with specified opener"
    echo "                      e.g., --open terminal, --open codium"
    echo "  --init              run pnpm install + rhx upgrade in background"
    echo ""
    echo "behavior:"
    echo "  - if worktree exists: keeps it (idempotent)"
    echo "  - if branch exists (local/remote): fails (use 'git tree del' first)"
    echo "  - otherwise: creates new branch from --from target"
    return 0
  fi

  local branch="" opener="" from_target="" init_flag=false

  # parse args
  local prev=""
  for arg in "$@"; do
    if [[ "$prev" == "--from" ]]; then
      from_target="$arg"
      prev=""
      continue
    fi
    if [[ "$prev" == "--open" ]]; then
      opener="$arg"
      prev=""
      continue
    fi
    case "$arg" in
      --open) prev="--open" ;;
      --init) init_flag=true ;;
      --from) prev="--from" ;;
      -*) ;;
      *) [[ -z "$branch" ]] && branch="$arg" ;;
    esac
  done

  if [[ -z "$branch" ]]; then
    echo "usage: git tree set <branch> --from <main|tree> [--open <opener>]"
    return 1
  fi

  if [[ -z "$from_target" ]]; then
    echo "✋ --from <main|tree> is required"
    echo "   └─ usage: git tree set <branch> --from <main|tree> [--open <opener>]"
    return 1
  fi

  ####################################################################
  # `this` is the RETIRED spelling of `tree`
  #
  # .why the rename: this flag and `grove.provision --from` ask the SAME
  #      question — which of the two places on this machine? — so they must
  #      take the same answer set. two words for one concept is the defect
  #      `rule.forbid.domain-term-synonyms` blocks, and `tree` is the declared
  #      term (`term=tree._.choice._.md`)
  #
  # .why it fails rather than aliases: a silent alias keeps the synonym alive
  #      forever, since no run ever teaches the human the canonical word. one
  #      error, once, and the muscle memory moves
  ####################################################################
  if [[ "$from_target" == "this" ]]; then
    echo "✋ --from this is retired; the value is 'tree'" >&2
    echo "   ├─ fix: git tree set $branch --from tree" >&2
    echo "   └─ why: 'tree' is the declared word for this worktree, and the same" >&2
    echo "           pair (main|tree) is what 'grove.provision --from' takes" >&2
    return 2
  fi

  if [[ "$from_target" != "main" && "$from_target" != "tree" ]]; then
    echo "✋ --from must be 'main' or 'tree', got '$from_target'" >&2
    echo "   ├─ main = branch off origin/main" >&2
    echo "   └─ tree = branch off this tree's HEAD" >&2
    return 2
  fi

  if [[ "$prev" == "--open" ]]; then
    echo "error: --open requires an opener (e.g., --open terminal, --open codium)"
    return 1
  fi

  local repo_name worktrees_dir sanitized worktree_path
  repo_name="$(_git_tree_repo_name)"
  worktrees_dir="$(_git_tree_worktrees_dir)"
  sanitized="$(_git_tree_sanitize_branch "$branch")"
  worktree_path="$worktrees_dir/$repo_name.$sanitized"

  # NOT named `status`: zsh reserves `status` as a READ-ONLY special parameter
  # (its alias for `$?`), so `local status` dies with `read-only variable` — and
  # this file is sourced by an interactive ZSH. bash has no such reservation, so
  # the name passes every bash check and fails only in the human's shell
  local outcome sprouted_from commit_info

  # findsert: find or insert
  if [[ -d "$worktree_path" ]]; then
    outcome="found"
    # get current commit info from worktree found
    commit_info=$(_git_commit_line "$worktree_path")
    sprouted_from=""
  else
    outcome="created"
    mkdir -p "$worktrees_dir"

    # fail fast if branch already exists (--from implies new branch creation)
    if git show-ref --verify --quiet "refs/heads/$branch"; then
      echo "🌲 branch '$branch' already exists locally"
      echo -e "   ├─ \033[2mtry 'git tree get $branch --open <opener>' to open it\033[0m"
      echo -e "   └─ \033[2mtry 'git tree del $branch' to remove it\033[0m"
      return 1
    elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
      echo "🌲 branch '$branch' already exists on remote"
      echo -e "   ├─ \033[2mtry 'git tree get $branch --open <opener>' to open it\033[0m"
      echo -e "   └─ \033[2mtry 'git tree del $branch' to remove it\033[0m"
      return 1
    fi

    if [[ "$from_target" == "main" ]]; then
      # create from origin/main (or origin/master) with no upstream
      # (upstream is set later via git push -u)
      local base_ref="origin/main"
      git fetch origin main 2>/dev/null || base_ref="origin/master"
      sprouted_from="$base_ref"
      git worktree add -q --no-track -b "$branch" "$worktree_path" "$base_ref"
    else
      # create new branch from HEAD (--from tree) with no upstream
      sprouted_from=$(git branch --show-current)
      git worktree add -q --no-track -b "$branch" "$worktree_path"
    fi
    commit_info=$(_git_commit_line "$worktree_path")
  fi

  # viby output
  echo ""
  echo "🌲 $repo_name.$sanitized"
  echo "   ├─ status: $outcome"
  echo "   ├─ branch: $branch"
  echo "   ├─ path: $worktree_path"
  if [[ -n "$sprouted_from" ]]; then
    echo "   ├─ from: $sprouted_from"
  fi

  # build output lines after head
  local lines=()
  [[ "$init_flag" == "true" ]] && lines+=("will init in background...")
  [[ -n "$opener" ]] && lines+=("will open in $opener...")
  [[ -z "$opener" ]] && lines+=("tip: use --open <opener> to open (e.g., --open terminal, --open codium)")
  [[ "$init_flag" != "true" && -f "$worktree_path/package.json" ]] && lines+=("tip: use --init to run pnpm install + rhx upgrade in background")

  if [[ ${#lines[@]} -eq 0 ]]; then
    echo "   └─ head: $commit_info"
  else
    echo "   ├─ head: $commit_info"
    for ((i=0; i<${#lines[@]}; i++)); do
      if [[ $i -eq $((${#lines[@]} - 1)) ]]; then
        echo -e "   └─ \033[2m${lines[$i]}\033[0m"
      else
        echo -e "   ├─ \033[2m${lines[$i]}\033[0m"
      fi
    done
  fi
  echo ""

  # kick off pnpm install + rhx upgrade in background if requested and package.json exists
  #
  # ⚠️ BOUNDED. measured 2026-08-14: `pnpm install` against a listener that
  #    accepts and stays silent NEVER returned — cut at 240s over 5 attempts.
  #    this call is backgrounded and disowned, so a stall does not wedge the
  #    shell; it leaves an orphan that holds a node process and a lock forever,
  #    and the human sees only that `init complete` never prints.
  #
  # ⚠️ the numbers are a COPY of `WEB_REGISTRY_*_SECONDS` from
  #    `src/grove.web.sh`, for the same reason the zshrc copy exists: an
  #    installed shell artifact must work on a box with no checkout. clamped by
  #    `prove.registry-bounds-agree`.
  #
  # 🛑 `-k 30` is what makes the 900 a bound rather than a request. `timeout`
  #    alone sends TERM, which pnpm may ignore mid-transaction — measured
  #    2026-08-14, a bare timeout did not end a TERM-deaf child at 5× its limit
  #    (`prove.timeouts-kill-what-they-cut`). here the cost of the miss is the
  #    orphan named above, held for the life of the box rather than 900s
  if [[ "$init_flag" == "true" && -f "$worktree_path/package.json" ]]; then
    (
      cd "$worktree_path" && \
      timeout -k 30 900 pnpm install --silent --fetch-timeout 60000 2>/dev/null && \
      rhx upgrade 2>/dev/null && \
      echo "🐢 init complete for $repo_name.$sanitized"
    ) &
    disown
  fi

  # open with specified opener if requested
  # note: subshell ensures opener inherits correct cwd, without mutate of parent shell
  if [[ -n "$opener" ]]; then
    (cd "$worktree_path" && "$opener" .) &
  fi
}

# .what: remove worktree for branch
_git_tree_del() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "git tree del - remove worktree for branch"
    echo ""
    echo "usage: git tree del <branch>"
    echo "       git tree del --this"
    echo "       git tree del --repo <name> --name <branch>"
    echo ""
    echo "options:"
    echo "  --this           delete current branch (with safety guards)"
    echo "  --repo <name>    specify repo (scans ~/git/*/_worktrees/)"
    echo "  --name <branch>  specify branch (use with --repo)"
    echo ""
    echo "removes the worktree directory and prunes git references"
    echo "safe to run if worktree doesn't exist (no-op)"
    echo ""
    echo "--this guards:"
    echo "  - no staged changes"
    echo "  - no unstaged changes"
    echo "  - no untracked files"
    echo "  - no open (unmerged) PR for branch"
    return 0
  fi

  local branch=""
  local repo_filter=""
  local delete_branch=false

  # parse args
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --this)
        branch="--this"
        shift
        ;;
      --repo)
        repo_filter="$2"
        shift 2
        ;;
      --name)
        branch="$2"
        shift 2
        ;;
      *)
        # positional: treat as branch name (backwards compat)
        branch="$1"
        shift
        ;;
    esac
  done

  # handle --this: delete current branch with guards
  if [[ "$branch" == "--this" ]]; then
    delete_branch=true
    local current_branch git_root
    current_branch=$(git branch --show-current 2>/dev/null)
    git_root=$(git rev-parse --show-toplevel 2>/dev/null)

    if [[ -z "$current_branch" ]]; then
      echo "⛈️  not on a branch (detached HEAD?)"
      return 1
    fi

    if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
      echo "⛈️  cannot delete $current_branch"
      return 1
    fi

    # must be in a worktree, not main repo
    if [[ ! "$git_root" == *"_worktrees"* ]]; then
      echo "⛈️  not in a worktree (use 'git tree del <branch>' from main repo)"
      return 1
    fi

    echo ""
    echo "🍂 '$current_branch'"

    # guard: no staged changes
    if ! git diff --cached --quiet 2>/dev/null; then
      echo "   └─ ⛈️  has staged changes"
      return 1
    fi

    # guard: no unstaged changes
    if ! git diff --quiet 2>/dev/null; then
      echo "   └─ ⛈️  has unstaged changes"
      return 1
    fi

    # guard: no untracked files
    if [[ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]]; then
      echo "   └─ ⛈️  has untracked files"
      return 1
    fi

    # guard: no open PR for this branch
    local open_pr
    open_pr=$(gh pr list --head "$current_branch" --state open --json number --limit 1 2>/dev/null | jq -r '.[0].number // empty')
    if [[ -n "$open_pr" ]]; then
      echo "   └─ ⛈️  has open PR #$open_pr"
      return 1
    fi

    echo "   └─ 👌 all guards passed"

    # now delete the branch (can rm current dir while in it)
    branch="$current_branch"
  fi

  if [[ -z "$branch" ]]; then
    echo "usage: git tree del <branch>"
    echo "       git tree del --repo <name> --name <branch>"
    return 1
  fi

  local repo_name worktrees_dir sanitized worktree_path

  if [[ -n "$repo_filter" ]]; then
    # find repo via scan of ~/git/*/_worktrees/
    # ⚠️ `find`, not a bare glob — a box with no `_worktrees` dir anywhere is
    #    the state of a FRESH machine, and there zsh aborts the whole function
    #    (`rule.forbid.bare-globs-in-dual-shell-files`)
    while IFS= read -r wdir; do
      [[ -d "$wdir" ]] || continue
      sanitized="$(_git_tree_sanitize_branch "$branch")"
      if [[ -d "$wdir/$repo_filter.$sanitized" ]]; then
        repo_name="$repo_filter"
        worktrees_dir="$wdir"
        worktree_path="$wdir/$repo_filter.$sanitized"
        break
      fi
    done < <(find ~/git -mindepth 2 -maxdepth 2 -type d -name '_worktrees' 2>/dev/null | sort)
    if [[ -z "$worktree_path" ]]; then
      echo "🍃 $repo_filter.$sanitized"
      echo "   ├─ status: not found"
      echo -e "   └─ \033[2mno worktree for this repo/branch\033[0m"
      return 0
    fi
  else
    repo_name="$(_git_tree_repo_name)"
    worktrees_dir="$(_git_tree_worktrees_dir)"
    sanitized="$(_git_tree_sanitize_branch "$branch")"
    worktree_path="$worktrees_dir/$repo_name.$sanitized"
  fi

  echo ""

  # guard: only delete paths inside _worktrees
  if [[ ! "$worktree_path" == *"_worktrees"* ]]; then
    echo "⛈️  safety: path not inside _worktrees, abort"
    echo "   └─ path: $worktree_path"
    return 1
  fi

  if [[ -d "$worktree_path" ]]; then
    local commit_info
    commit_info=$(_git_commit_line "$worktree_path")

    local main_repo
    # extract main repo from worktree .git file (gitdir pointer)
    main_repo=$(git -C "$worktree_path" rev-parse --show-superproject-working-tree 2>/dev/null)
    [[ -z "$main_repo" ]] && main_repo=$(git -C "$worktree_path" rev-parse --git-common-dir 2>/dev/null | sed 's|/\.git$||; s|/\.git/worktrees/.*||')

    git -C "$main_repo" worktree remove "$worktree_path" --force 2>/dev/null || {
      # chmod only in fallback (pnpm/jest can create restricted permissions)
      chmod -R u+rwX "$worktree_path" 2>/dev/null || {
        echo "⚠️  cannot chmod worktree (permission denied without sudo)"
        echo "   └─ fix: sudo chmod -R u+rwX \"$worktree_path\""
        return 1
      }
      rm -rf "$worktree_path"
      git -C "$main_repo" worktree prune >/dev/null 2>&1
    }
    echo "🍂 $repo_name.$sanitized"
    echo "   ├─ status: removed"
    echo "   ├─ branch: $branch"
    if [[ "$delete_branch" == "true" ]]; then
      git -C "$main_repo" branch -D "$branch" 2>/dev/null
      git -C "$main_repo" push origin --delete "$branch" 2>/dev/null
      echo "   ├─ was at: $commit_info"
      echo "   └─ branch deleted (local + remote)"
    else
      echo "   └─ was at: $commit_info"
    fi
  else
    if [[ "$delete_branch" == "true" ]]; then
      # no worktree but still delete the branch - need to find repo another way
      local main_repo
      main_repo="$(dirname "$worktrees_dir")"
      [[ ! -d "$main_repo/.git" ]] && main_repo="$main_repo/$repo_name"
      git -C "$main_repo" branch -D "$branch" 2>/dev/null
      git -C "$main_repo" push origin --delete "$branch" 2>/dev/null
      echo "🍂 $branch"
      echo "   └─ branch deleted (local + remote)"
    else
      echo "🍃 $repo_name.$sanitized"
      echo "   ├─ status: not found"
      echo -e "   └─ \033[2mmay have already been deleted\033[0m"
    fi
  fi
  echo ""
}

# .what: convert epoch to relative time string (e.g., "3h ago", "2d ago")
# args: epoch_seconds
_git_tree_relative_time() {
  local epoch="$1"
  local now diff
  now=$(date +%s)
  diff=$((now - epoch))

  if [[ $diff -lt 3600 ]]; then
    echo "$((diff / 60))m ago"
  elif [[ $diff -lt 86400 ]]; then
    echo "$((diff / 3600))h ago"
  elif [[ $diff -lt 604800 ]]; then
    echo "$((diff / 86400))d ago"
  elif [[ $diff -lt 2592000 ]]; then
    echo "$((diff / 604800))w ago"
  elif [[ $diff -lt 31536000 ]]; then
    echo "$((diff / 2592000)) mo ago"
  else
    echo "1y+ ago"
  fi
}

# .what: convert epoch to date string (e.g., "May 26")
# args: epoch_seconds
_git_tree_format_date() {
  local epoch="$1"
  date -d "@$epoch" "+%b %-d" 2>/dev/null || echo "unknown"
}

# .what: print status for a single worktree directory
# args: dir, repo_name, is_last (true/false), timestamp (optional)
_git_tree_status_one() {
  local dir="$1"
  local repo_name="$2"
  local is_last="$3"
  local mtime="$4"
  local name branch_name display_branch
  name=$(basename "$dir")
  branch_name=$(echo "$name" | sed "s/^${repo_name}\\.//")
  display_branch=$(echo "$branch_name" | tr '.' '/')

  # tree connectors
  local tree_conn="├─"
  local child_prefix="│  "
  if [[ "$is_last" == "true" ]]; then
    tree_conn="└─"
    child_prefix="   "
  fi

  # get worktree timestamps
  local created_epoch mtime_epoch created_fmt mtime_fmt relative
  created_epoch=$(stat -c %W "$dir" 2>/dev/null || echo "0")
  mtime_epoch="${mtime:-$(stat -c %Y "$dir" 2>/dev/null || echo "0")}"
  # fallback: if birth time is 0, use mtime
  [[ "$created_epoch" == "0" ]] && created_epoch="$mtime_epoch"
  created_fmt=$(_git_tree_format_date "$created_epoch")
  mtime_fmt=$(_git_tree_format_date "$mtime_epoch")
  relative=$(_git_tree_relative_time "$mtime_epoch")

  echo "   $tree_conn 🌲 $display_branch"
  echo -e "   $child_prefix  ├─ \033[2mat $dir\033[0m"
  echo -e "   $child_prefix  ├─ \033[2mon $created_fmt → $mtime_fmt, $relative\033[0m"

  # check local state (env -i to fully isolate from current repo's git env)
  local has_staged has_unstaged has_untracked
  has_staged=$(env -i PATH="$PATH" git -C "$dir" diff --cached --quiet 2>/dev/null; echo $?)
  has_unstaged=$(env -i PATH="$PATH" git -C "$dir" diff --quiet 2>/dev/null; echo $?)
  has_untracked=$(env -i PATH="$PATH" git -C "$dir" ls-files --others --exclude-standard 2>/dev/null | head -1)

  # count commits beyond merge-base with main
  local merge_base commit_count first_commit_msg
  merge_base=$(env -i PATH="$PATH" git -C "$dir" merge-base HEAD origin/main 2>/dev/null || env -i PATH="$PATH" git -C "$dir" merge-base HEAD origin/master 2>/dev/null || echo "")
  if [[ -n "$merge_base" ]]; then
    commit_count=$(env -i PATH="$PATH" git -C "$dir" rev-list --count "$merge_base"..HEAD 2>/dev/null || echo "0")
    if [[ "$commit_count" != "0" ]]; then
      # ⚠️ the ONE subject `_git_commit_line` cannot serve: a different format
      #    (`%s` alone), a range, and an `env -i` scope. it rides the SAME sink,
      #    which is the fact both share — read the 🛑 on `_git_commit_line` for
      #    why a raw subject may never reach a terminal
      first_commit_msg=$(env -i PATH="$PATH" git -C "$dir" log --reverse --format="%s" "$merge_base"..HEAD 2>/dev/null | head -1 | __duct_strip_escapes)
    fi
  else
    commit_count="0"
  fi

  # check remote state
  local ahead_count behind_count pr_state repo_remote
  ahead_count=$(env -i PATH="$PATH" git -C "$dir" rev-list --count @{upstream}..HEAD 2>/dev/null || echo "0")
  behind_count=$(env -i PATH="$PATH" git -C "$dir" rev-list --count HEAD..@{upstream} 2>/dev/null || echo "0")
  repo_remote=$(env -i PATH="$PATH" git -C "$dir" remote get-url origin 2>/dev/null | sed 's|.*github.com[:/]||; s|\.git$||')
  pr_state=$(gh pr view "$display_branch" --repo "$repo_remote" --json state --jq '.state' 2>/dev/null || echo "")

  # build issues list
  local issues=()
  [[ "$has_staged" != "0" || "$has_unstaged" != "0" || -n "$has_untracked" ]] && issues+=("unstaged")
  [[ "$ahead_count" != "0" && "$ahead_count" != "" ]] && issues+=("unpushed ($ahead_count)")
  [[ "$behind_count" != "0" && "$behind_count" != "" ]] && issues+=("unpulled ($behind_count)")
  [[ "$pr_state" == "OPEN" ]] && issues+=("unmerged")
  [[ "$pr_state" == "CLOSED" ]] && issues+=("closed")

  # determine status output
  if [[ "$pr_state" == "MERGED" ]]; then
    echo "   $child_prefix  └─ 👌 merged"
  elif [[ "$commit_count" == "0" && ${#issues[@]} -eq 0 ]]; then
    echo "   $child_prefix  └─ 🫧 no work"
  elif [[ ${#issues[@]} -gt 0 ]]; then
    local issues_str
    issues_str=$(IFS=,; echo "${issues[*]}" | sed 's/,/, /g')
    if [[ -n "$first_commit_msg" ]]; then
      echo "   $child_prefix  ├─ ✋ $issues_str"
      echo "   $child_prefix  └─ 🌱 $first_commit_msg"
    else
      echo "   $child_prefix  └─ ✋ $issues_str"
    fi
  else
    # has commits, no issues, no pr
    if [[ -n "$first_commit_msg" ]]; then
      echo "   $child_prefix  ├─ ✋ no pr"
      echo "   $child_prefix  └─ 🌱 $first_commit_msg"
    else
      echo "   $child_prefix  └─ ✋ no pr"
    fi
  fi
}

# .what: show status of all worktrees (deletable, dirty, ahead, etc)
_git_tree_status() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "git tree status - show worktree status and deletability"
    echo ""
    echo "usage: git tree status [--repo <name|@all>]"
    echo ""
    echo "options:"
    echo "  --repo @all    show worktrees across all repos on machine"
    echo "  --repo <name>  show worktrees for specific repo"
    echo ""
    echo "status icons:"
    echo "  👌 merged      safe to delete"
    echo "  🫧 no work     no commits on branch"
    echo "  ✋ issues      unstaged, unpushed, unmerged, etc"
    echo "  🌱 first commit message on branch"
    return 0
  fi

  # declare all loop variables at function scope to avoid zsh local output quirks
  local repo_filter="" found_any=false repos=() entries=() sorted=()
  local rname timestamp dir entry idx total is_last repo_name worktrees_dir

  if [[ "$1" == "--repo" && -n "$2" ]]; then
    repo_filter="$2"
  fi

  if [[ -n "$repo_filter" ]]; then
    # scan all ~/git/*/_worktrees/ directories

    # ⚠️ every walk below is `find`-fed, never a bare glob — zsh reads this
    #    file, and there a glob that matches no file aborts the whole function.
    #    a fresh box has no `_worktrees` at all, and a `_worktrees` with no
    #    worktree is the normal state after a prune
    #    (`rule.forbid.bare-globs-in-dual-shell-files`)
    while IFS= read -r worktrees_dir; do
      [[ -d "$worktrees_dir" ]] || continue

      # collect unique repo names in this worktrees dir
      repos=()
      while IFS= read -r dir; do
        [[ -d "$dir" ]] || continue
        [[ "$(basename "$dir")" == "_patches" ]] && continue
        rname=$(basename "$dir" | cut -d. -f1)
        # filter by repo name unless @all
        if [[ "$repo_filter" != "@all" && "$rname" != "$repo_filter" ]]; then
          continue
        fi
        if [[ ! " ${repos[*]} " =~ " ${rname} " ]]; then
          repos+=("$rname")
        fi
      done < <(find "$worktrees_dir" -mindepth 1 -maxdepth 1 2>/dev/null | sort)

      for repo_name in "${repos[@]}"; do
        entries=()
        while IFS= read -r dir; do
          [[ -d "$dir" ]] || continue
          timestamp=$(stat -c %Y "$dir" 2>/dev/null || echo "0")
          entries+=("$timestamp:$dir")
        done < <(find "$worktrees_dir" -mindepth 1 -maxdepth 1 -name "$repo_name".'*' 2>/dev/null | sort)

        [[ ${#entries[@]} -eq 0 ]] && continue

        found_any=true

        # sort by timestamp (most recent first)
        IFS=$'\n' sorted=($(printf '%s\n' "${entries[@]}" | sort -t: -k1 -rn)); unset IFS

        echo ""
        echo "🏔️  $repo_name"
        echo "   │"

        idx=0
        total=${#sorted[@]}
        for entry in "${sorted[@]}"; do
          ((idx++))
          timestamp="${entry%%:*}"
          dir="${entry#*:}"
          is_last="false"
          [[ $idx -eq $total ]] && is_last="true"
          _git_tree_status_one "$dir" "$repo_name" "$is_last" "$timestamp"
          [[ "$is_last" == "false" ]] && echo "   │"
        done
      done
    done < <(find ~/git -mindepth 2 -maxdepth 2 -type d -name '_worktrees' 2>/dev/null | sort)

    if [[ "$found_any" == "false" ]]; then
      echo ""
      if [[ "$repo_filter" == "@all" ]]; then
        echo "🏔️  (no worktrees on machine)"
      else
        echo "🏔️  $repo_filter"
        echo "   └─ (no worktrees)"
      fi
    fi

    echo ""
    return 0
  fi

  # current repo only (variables already declared at function scope)
  worktrees_dir="$(_git_tree_worktrees_dir)"
  repo_name="$(_git_tree_repo_name)"

  if [[ ! -d "$worktrees_dir" ]]; then
    echo ""
    echo "🏔️  $repo_name"
    echo "   └─ (no worktrees)"
    echo ""
    return 0
  fi

  entries=()
  # ⚠️ `find`, not a bare glob — the `-d` guard above proves the dir EXISTS,
  #    which is not the claim that it holds a worktree. under zsh a no-match
  #    glob aborts the function before the `-eq 0` arm below can report it
  #    (`rule.forbid.bare-globs-in-dual-shell-files`)
  while IFS= read -r dir; do
    [[ -d "$dir" ]] || continue
    timestamp=$(stat -c %Y "$dir" 2>/dev/null || echo "0")
    entries+=("$timestamp:$dir")
  done < <(find "$worktrees_dir" -mindepth 1 -maxdepth 1 -name "$repo_name".'*' 2>/dev/null | sort)

  if [[ ${#entries[@]} -eq 0 ]]; then
    echo ""
    echo "🏔️  $repo_name"
    echo "   └─ (no worktrees)"
    echo ""
    return 0
  fi

  # sort by timestamp (most recent first)
  IFS=$'\n' sorted=($(printf '%s\n' "${entries[@]}" | sort -t: -k1 -rn)); unset IFS

  echo ""
  echo "🏔️  $repo_name"
  echo "   │"

  idx=0
  total=${#sorted[@]}
  for entry in "${sorted[@]}"; do
    ((idx++))
    timestamp="${entry%%:*}"
    dir="${entry#*:}"
    is_last="false"
    [[ $idx -eq $total ]] && is_last="true"
    _git_tree_status_one "$dir" "$repo_name" "$is_last" "$timestamp"
    [[ "$is_last" == "false" ]] && echo "   │"
  done

  echo ""
}

######################
## git graft helper (invoked by git alias.graft)
##
## what: replay specific commits onto a different base
##
## why: enables cascade PRs by cherry-pick of commits onto a new base
##      works even when original base was rebased or squash-merged
##
## how:
##   git graft --onto main --from B1              # plan B1..HEAD (default)
##   git graft --onto main --from B1 --till B3   # plan B1..B3
##   git graft --onto main --from B1 --mode apply # execute
##
## note: uses cherry-pick, not rebase. --from is inclusive, --till defaults to HEAD.
######################

# .what = the path of the worktree that holds a branch, or empty for none
#
# .why  = `git graft` ends with `git branch -f "$b" HEAD`, which OVERWRITES the
#         branch pointer. if another worktree has it checked out, that worktree's
#         HEAD and index now describe a commit nobody put there — so both call
#         sites refuse first, and this is the read they refuse on.
#
# 🛑 .match `branch refs/heads/<name>` with `-Fx`, never a `[<name>]` pattern
#     📜 measured 2026-08-31: `--porcelain` emits `branch refs/heads/<name>` and
#     NEVER the `[<name>]` form, which belongs to the plain output. so
#     `grep -B2 "\[${branch}\]"` matches no line on any repo, the guard returns
#     empty on every run, and the `branch -f` below it always goes through. a
#     guard that cannot fire is a false ✔ on a destructive step
#     (`rule.forbid.failhide`).
#
#     ⇒ a BRE with a branch name interpolated into it also misreads a name that
#       holds a `.` or a `*`, even against the right text. `-Fx` retires both:
#       a FIXED string, matched as a WHOLE line.
#
# ⚠️ .why one helper and not the rule twice
#      the two call sites are the `--continue` path and the straight-through
#      path. one rule, two holders, free to drift
#      (m.9, `rule.forbid.two-writers-on-one-artifact`).
_git_graft_worktree_of() {
  local branch="$1"
  [[ -z "$branch" ]] && return 0
  git worktree list --porcelain 2>/dev/null \
    | grep -B2 -Fx "branch refs/heads/${branch}" \
    | grep '^worktree ' | head -1 | sed 's/^worktree //'
}

# .what: main entry for git graft
git_alias_graft() {
  local graft_state="$(git rev-parse --git-dir)/GRAFT_ORIG_HEAD"

  # handle --continue
  if [[ "$1" == "--continue" ]]; then
    if [[ ! -f "$graft_state" ]]; then
      echo "error: no graft in progress"
      return 1
    fi
    local branch
    branch=$(head -1 "$graft_state")
    if git cherry-pick --continue; then
      # reject if branch is checked out in another worktree
      local worktree_path
      worktree_path=$(_git_graft_worktree_of "$branch")
      if [[ -n "$worktree_path" ]]; then
        echo ""
        echo "   ⛈️  branch '$branch' is checked out in worktree: $worktree_path"
        echo "   └─ close that worktree first, then: git graft --continue"
        return 1
      fi
      # move branch pointer to completed result and checkout
      git branch -f "$branch" HEAD
      git checkout "$branch"
      rm -f "$graft_state"
      echo ""
      echo "🌲 graft complete"
      echo ""
      return 0
    fi
    return $?
  fi

  # handle --abort
  if [[ "$1" == "--abort" ]]; then
    if [[ ! -f "$graft_state" ]]; then
      echo "error: no graft in progress"
      return 1
    fi
    local branch
    branch=$(head -1 "$graft_state")
    git cherry-pick --abort 2>/dev/null
    git checkout "$branch"
    rm -f "$graft_state"
    echo ""
    echo "🌲 graft aborted, restored to $branch"
    echo ""
    return 0
  fi

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "git graft - replay commits onto a different base"
    echo ""
    echo "usage: git graft --onto <newbase> --from <commit> [--till <commit>] [--mode plan|apply]"
    echo "       git graft --continue"
    echo "       git graft --abort"
    echo ""
    echo "options:"
    echo "  --onto <ref>     the new base to replay commits onto"
    echo "  --from <commit>  first commit to include (inclusive)"
    echo "  --till <commit>  last commit to include (default: HEAD)"
    echo "  --mode plan      preview commits (default)"
    echo "  --mode apply     execute the graft"
    echo "  --continue       resume after conflicts are resolved"
    echo "  --abort          cancel graft and restore original HEAD"
    echo ""
    echo "examples:"
    echo "  git graft --onto origin/main --from abc123              # plan abc123..HEAD"
    echo "  git graft --onto main --from abc123 --till def456"
    echo "  git graft --onto main --from abc123 --mode apply # execute"
    echo ""
    echo "uses cherry-pick internally. safe for rebased/squashed bases."
    echo "commits already in --onto are excluded (ancestry filter)."
    return 0
  fi

  local onto="" from="" till="HEAD" mode="plan"

  # parse args
  local prev=""
  for arg in "$@"; do
    if [[ "$prev" == "--onto" ]]; then
      onto="$arg"
      prev=""
      continue
    fi
    if [[ "$prev" == "--from" ]]; then
      from="$arg"
      prev=""
      continue
    fi
    if [[ "$prev" == "--till" ]]; then
      till="$arg"
      prev=""
      continue
    fi
    if [[ "$prev" == "--mode" ]]; then
      mode="$arg"
      prev=""
      continue
    fi
    case "$arg" in
      --onto) prev="--onto" ;;
      --from) prev="--from" ;;
      --till) prev="--till" ;;
      --mode) prev="--mode" ;;
      *)
        echo "error: unknown argument '$arg'"
        echo "usage: git graft --onto <newbase> --from <commit> [--till <commit>] [--mode plan|apply]"
        return 1
        ;;
    esac
  done

  # validate mode
  if [[ "$mode" != "plan" && "$mode" != "apply" ]]; then
    echo "error: --mode must be 'plan' or 'apply'"
    return 1
  fi

  # validate required args
  if [[ -z "$onto" ]]; then
    echo "error: --onto is required"
    echo "usage: git graft --onto <newbase> --from <commit>"
    return 1
  fi

  # reject bare branch names — require origin/ prefix to avoid stale local refs
  # (if someone wants a specific commit, they can use a SHA)
  if [[ "$onto" != origin/* && ! "$onto" =~ ^[0-9a-f]{6,40}$ ]]; then
    echo "error: --onto '$onto' must use origin/ prefix (e.g., origin/$onto)"
    echo "   └─ bare branch names can be stale; use origin/ or a commit SHA"
    return 1
  fi

  if [[ -z "$from" ]]; then
    echo "error: --from is required"
    echo "usage: git graft --onto <newbase> --from <commit>"
    return 1
  fi

  local current_branch
  current_branch=$(git branch --show-current 2>/dev/null)

  if [[ -z "$current_branch" ]]; then
    echo "error: not on a branch (detached HEAD?)"
    return 1
  fi

  # get list of commits to cherry-pick
  # from^ makes --from inclusive
  # ^${onto} excludes commits already reachable from onto (ancestry filter)
  local commits
  commits=$(git rev-list --reverse "${from}^..${till}" "^${onto}" 2>/dev/null)

  if [[ -z "$commits" ]]; then
    echo "error: no commits found in range '${from}..${till}' (after ancestry filter)"
    return 1
  fi

  local commit_count
  commit_count=$(echo "$commits" | wc -l | tr -d ' ')

  echo ""
  echo "🌲 graft ($mode)"
  echo "   ├─ branch: $current_branch"
  echo "   ├─ onto: $onto"
  echo "   ├─ from: $from"
  echo "   ├─ till: $till"
  echo "   ├─ commits: $commit_count"

  # show commits
  local idx=0
  for commit in $commits; do
    ((idx++))
    local info
    # `.` is this repo — the loop already stands in it. the commit is a rev, and
    # its subject is remote-chosen text (see `_git_commit_line`)
    info=$(_git_commit_line . "$commit")
    if [[ "$idx" -eq "$commit_count" && "$mode" == "plan" ]]; then
      echo "   │  └─ $info"
    else
      echo "   │  ├─ $info"
    fi
  done

  if [[ "$mode" == "plan" ]]; then
    echo "   └─ use --mode apply to execute"
    echo ""
    return 0
  fi

  echo "   └─ ..."

  # reject if work tree is dirty
  if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    echo ""
    echo "   ⛈️  work tree is dirty — commit or stash changes before apply"
    return 1
  fi

  # save branch name for recovery (branch itself is never touched until success)
  echo "$current_branch" > "$graft_state"

  # detach to onto target (original branch stays safe)
  if ! git checkout --detach "$onto" >/dev/null 2>&1; then
    echo ""
    echo "   └─ ⛈️  failed to checkout '$onto'"
    rm -f "$graft_state"
    return 1
  fi

  # cherry-pick the commits in detached HEAD
  if ! git cherry-pick $commits >/dev/null 2>&1; then
    echo ""
    echo "   🟡 cherry-pick conflict!"
    echo "   ├─ resolve conflicts, then: git graft --continue"
    echo "   └─ or abort: git graft --abort"
    return 1
  fi

  # reject if branch is checked out in another worktree
  local worktree_path
  worktree_path=$(_git_graft_worktree_of "$current_branch")
  if [[ -n "$worktree_path" ]]; then
    echo ""
    echo "   ⛈️  branch '$current_branch' is checked out in worktree: $worktree_path"
    echo "   └─ close that worktree first, then: git graft --continue"
    return 1
  fi

  # success: move branch pointer to result and checkout
  git branch -f "$current_branch" HEAD
  git checkout "$current_branch"
  rm -f "$graft_state"

  echo ""
  echo "🌲 graft complete"
  echo "   ├─ $commit_count commits replayed"
  echo "   └─ branch: $current_branch now based on $onto"
  echo ""
}

######################
## git grab helper (invoked by git alias.grab)
##
## what: save and transfer patches between worktrees
##
## why: enables moving uncommitted changes to a different worktree
##      useful when you decide changes should go on their own branch
##
## how:
##   git grab set <name>                    # save both staged+unstaged changes
##   git grab set <name> --scope staged     # save only staged changes
##   git grab set <name> --scope unstaged   # save only unstaged changes
##   git grab get                           # list available patches
##   git grab get <name>                    # plan (preview) a patch
##   git grab get <name> --mode apply       # apply and consume a patch
##   git grab del <name>                    # delete a patch
##
## patch location: @gitroot/../_worktrees/_patches/<name>.patch
######################

# .what: get patches directory
_git_grab_patches_dir() {
  local worktrees_dir
  worktrees_dir="$(_git_tree_worktrees_dir)"
  echo "$worktrees_dir/_patches"
}

# .what: main dispatcher for git grab commands
######################
## what: manage groves (machines that hold trees) — set, list, get, del, send, read
##
## why: a grove is a remote machine. git grove is the sibling of git tree:
##      git tree manages branch workspaces; git grove manages the machines.
##      see .agent/repo=.this/role=any/briefs/grove/reach/define.git-forest-grove-tree.md
##
## how:
##   git grove set <name> --at <user@host:port>  # register a grove (+ ssh alias)
##   git grove list                              # list registered groves (forest view)
##   git grove get <name>                        # show one grove + how to reach it
##   git grove del <name>                        # unregister a grove (+ drop ssh alias)
##   git grove del --orphaned                    # plan: which entries have no live instance
##   git grove del --orphaned --mode apply       # drop them
##   git grove send <name> --what "<cmd>"        # run a command in the grove's duct
##   git grove read <name>                       # read the grove's duct output
##
## registry: ~/.git.forest/groves/<name>.json — one file per grove (no write conflicts)
## transport: send/read delegate to ductwork (--on duct://<alias>/main/mechanic)
##            the session follows ductwork's <tree>/<role> grammar; the URI is
##            built once by _git_grove_duct_uri, never spelled at a call site
##
## .note = near-term bash bootstrap. the long-term home is a global rhachet skill
##         (rhx git.grove) in the ghlitch role, so it is allowlistable for agents.
##         grove wake/hibernate is a separate infra declastruct primitive — deferred,
##         not part of this bash triad. see .dream/2026_07_24.git-grove-skills.dream.md
######################

# .what: the grove registry dir
_git_grove_dir() { echo "$HOME/.git.forest/groves"; }

######################################################################
# 🛑 a grove-registry VALUE becomes an ~/.ssh/config DIRECTIVE, and that file
#    is an EXECUTION SURFACE
#
# .what = refuse a value that holds a byte outside its grammar.
#
# .why  = the registry record is not inert data. TWO roads carry it into
#         `~/.ssh/config`, and both end at code this laptop runs:
#
#           1. `git grove wake` reads the record and writes
#              `Host / HostName / Port / User / IdentityFile` from it.
#              ssh_config is NEWLINE-DELIMITED, so one `\n` in a value adds a
#              directive of the writer's choice — and `ProxyCommand` is a
#              command run on every later `ssh <that host>`.
#
#           2. `_git_grove_del` strips the block it wrote. splice `.sshAlias`
#              into a **sed address** over that same file with `-i` and a `/`
#              in the alias ends the address, so whatever follows is a sed
#              COMMAND — an arbitrary rewrite of the human's ssh config.
#
#         ⇒ two roads, one file, one outcome. a grammar at the door closes the
#           class; a fix on either road alone leaves the other
#           (`rule.require.solve-at-cause`).
#
# ⚠️ `git.grove.wake` clamps the same fields on the READ side, and that is a
#    second BOUNDARY rather than a second copy: this record is a FILE, which a
#    human may edit by hand or another tool may write, and a writer's check
#    says none about what a reader is handed (`rule.require.trust-but-verify`).
######################################################################
_git_grove_clamp() {
  local field="$1" value="$2" allowed="$3" shape="$4"
  [[ -z "$value" ]] && return 0
  if [[ "$value" == *[!$allowed]* ]]; then
    echo "✋ $field holds a byte outside its grammar" >&2
    echo "   allowed: $shape" >&2
    echo "   ⇒ this value is stored, then written into ~/.ssh/config by" >&2
    echo "     'git grove wake'. a newline there adds a directive, and one of" >&2
    echo "     them — ProxyCommand — runs a command on THIS box" >&2
    return 2
  fi
  return 0
}

# .what: main dispatcher for git grove commands
git_alias_grove() {
  local cmd="${1:-list}"
  shift 2>/dev/null || true

  case "$cmd" in
    -h|--help)
      echo "git grove - manage groves (machines that hold trees)"
      echo ""
      echo "usage: git grove <command> [options]"
      echo ""
      echo "commands:"
      echo "  set <name> --at <user@host:port>  register a grove (writes an ssh Host block)"
      echo "  set <name> --alias <ssh-alias>    register a grove on an EXTANT ssh alias"
      echo "  set <name> --exid <tag> --env <e> register a cloud grove, found by tag"
      echo "  wake <name>                       resume the box + open its duct"
      echo "  stop <name>                       hibernate the box"
      echo "  list                              list registered groves"
      echo "  get <name>                        show one grove"
      echo "  del <name>                        unregister a grove"
      echo "  del --orphaned [--mode apply]     unregister every grove whose instance is gone"
      echo "  send <name> --what \"<cmd>\"        run a command in the grove's duct"
      echo "  read <name>                       read the grove's duct output"
      return 0
      ;;
    set) _git_grove_set "$@" ;;
    wake) rhx git.grove.wake "$@" ;;
    stop) rhx git.grove.stop "$@" ;;
    list) _git_grove_list "$@" ;;
    get) _git_grove_get "$@" ;;
    del) _git_grove_del "$@" ;;
    send) _git_grove_send "$@" ;;
    read) _git_grove_read "$@" ;;
    *)
      echo "error: unknown command '$cmd'"
      echo "run 'git grove --help' for usage"
      return 1
      ;;
  esac
}

# .what: register a grove — write registry json, and an ssh Host block when we own the alias
#
# two modes:
#   --at <user@host:port>   we own the alias: write an ssh Host block named after the grove
#   --alias <name>          ssh owns the alias: reuse an extant ssh Host, write no block
#                           (use when infra/declastruct already wrote the ssh config —
#                            keys, ProxyCommand, SSM tunnel, etc)
#   both                    grove name stays semantic; the named alias carries the address
_git_grove_set() {
  local name="" at="" alias="" exid="" env="" account="" nat=""
  # ⚠️ a `*_given` marker per flag, because "absent" and "empty" must differ:
  #    an absent flag INHERITS the extant entry's field, and `--nat ''` CLEARS
  #    it. a test on the value alone cannot tell those two apart — see the
  #    ⚠️ block below the parse for the entry this distinction protects
  local at_given=0 alias_given=0 exid_given=0 env_given=0 account_given=0 nat_given=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --at) at="$2"; at_given=1; shift 2 ;;
      --alias) alias="$2"; alias_given=1; shift 2 ;;
      --exid) exid="$2"; exid_given=1; shift 2 ;;
      --env) env="$2"; env_given=1; shift 2 ;;
      --account) account="$2"; account_given=1; shift 2 ;;
      --nat) nat="$2"; nat_given=1; shift 2 ;;
      --) shift ;;
      -*) echo "✋ unknown flag '$1'" >&2; return 2 ;;
      *) [[ -z "$name" ]] && name="$1"; shift ;;
    esac
  done

  if [[ -z "$name" ]]; then
    echo "✋ usage: git grove set <name> [--at <user@host:port>] [--alias <ssh-alias>]" >&2
    echo "                             [--exid <tag>] [--env <env>] [--account <id>] [--nat <exid>]" >&2
    return 2
  fi
  # a cloud grove is addressable by its exid alone — the wake derives its address
  # by tag, so --at/--alias are not required when --exid is given
  #
  # ⚠️ this gate is about CREATION, so it applies only where no entry exists yet.
  #    a gate that fires on EVERY call refuses exactly what the field-level
  #    upsert below is for:
  #
  #      git grove set <name> --env prep       ← a lone field update
  #      ✋ give --at, --alias, or --exid       ← and the entry already had one
  #
  #    an address is what a NEW entry cannot do without. an extant entry already
  #    holds one, so to demand it again is to demand a value the caller would only
  #    restate — and a restated value is a value that can be restated WRONG
  if [[ ! -f "$(_git_grove_dir)/$name.json" && -z "$at" && -z "$alias" && -z "$exid" ]]; then
    echo "✋ give --at <user@host:port>, --alias <ssh-alias>, or --exid <tag>" >&2
    echo "   ⇒ no entry named '$name' exists yet, so this set CREATES one, and a" >&2
    echo "     grove with no address is a grove no command can reach" >&2
    return 2
  fi

  # the ssh alias ductwork will ride; defaults to the grove name
  local ssh_alias="${alias:-$name}"

  # parse user@host:port when given
  local user="" host="" port=""
  if [[ -n "$at" ]]; then
    user="${at%%@*}"
    local hostport="${at#*@}"
    host="${hostport%%:*}"
    port="${hostport#*:}"
    [[ "$port" == "$hostport" ]] && port=22   # no :port given → default 22
  fi

  # write registry json (one file per grove)
  local dir; dir="$(_git_grove_dir)"
  mkdir -p "$dir"
  local added_at; added_at="$(date +%s)"

  ####################################################################
  # ⚠️ a flag NOT given inherits the extant entry — it never clears it
  #
  # .why  a write of every field from its own locals turns a `set` that names
  #       one flag into a REPLACE of the whole record, blanking the rest. it is
  #       spelled `set`, which by `rule.require.get-set-gen-verbs` means
  #       "overwrite" — but the object it overwrites is the ENTRY, and a
  #       caller who names `--at` speaks about the ADDRESS.
  #
  #       .measured 2026-08-11 — a set that named only `--at` to declare a
  #       seat's user:
  #
  #         before  account <acct> · env camp · nat camp-nat
  #         after   account null   · env null · nat null
  #
  #       and the loss was invisible until the next `git.grove.ready.verify`,
  #       which halted at rung 1 with "the entry names no account". the
  #       command that caused it had printed `🌲 registered` and exit 0.
  #
  # ⇒ so the field-level semantic is an UPSERT: each flag given overwrites
  #   its own field, and each flag absent keeps what the entry already holds.
  #   to CLEAR a field, name it with an empty value (`--nat ''`).
  #
  # ⚠️ this is the same shape as the wake's ssh-alias block: a partial write
  #   that judges only what it was told, and silently discards every fact it
  #   was not
  ####################################################################
  local prior="$dir/$name.json"
  if [[ -f "$prior" ]]; then
    local keep
    # ⚠️ `--flag ''` must CLEAR, so the test is whether the flag appeared at
    #    all — tracked by the `*_given` markers set in the parse loop above —
    #    never whether its value is empty
    [[ "$at_given"      != 1 ]] && { keep="$(jq -r '.user // empty'    "$prior")"; [[ "$keep" != "null" ]] && user="${user:-$keep}"; }
    [[ "$at_given"      != 1 ]] && { keep="$(jq -r '.host // empty'    "$prior")"; [[ "$keep" != "null" ]] && host="${host:-$keep}"; }
    [[ "$at_given"      != 1 ]] && { keep="$(jq -r '.port // empty'    "$prior")"; [[ "$keep" != "null" ]] && port="${port:-$keep}"; }
    [[ "$exid_given"    != 1 ]] && { keep="$(jq -r '.exid // empty'    "$prior")"; [[ "$keep" != "null" ]] && exid="${exid:-$keep}"; }
    [[ "$env_given"     != 1 ]] && { keep="$(jq -r '.env // empty'     "$prior")"; [[ "$keep" != "null" ]] && env="${env:-$keep}"; }
    [[ "$account_given" != 1 ]] && { keep="$(jq -r '.account // empty' "$prior")"; [[ "$keep" != "null" ]] && account="${account:-$keep}"; }
    [[ "$nat_given"     != 1 ]] && { keep="$(jq -r '.nat // empty'     "$prior")"; [[ "$keep" != "null" ]] && nat="${nat:-$keep}"; }
    [[ "$alias_given"   != 1 ]] && { keep="$(jq -r '.sshAlias // empty' "$prior")"; [[ -n "$keep" && "$keep" != "null" ]] && ssh_alias="$keep"; }
  fi
  # 🛑 this is the ONE point where every field is final — argv has been read and
  #    the `prior` merge above has landed. the grammar is asked here, once; a
  #    clamp at each of the nine uses would be nine readers of one rule, free to
  #    drift (`gotcha.a-check-that-cries-wolf`, m.9). the full reason for the
  #    grammar itself lives on `_git_grove_clamp`
  _git_grove_clamp "the grove name" "$name"      'A-Za-z0-9._-' '[A-Za-z0-9._-]' || return 2
  _git_grove_clamp "--alias"        "$ssh_alias" 'A-Za-z0-9._-' '[A-Za-z0-9._-]' || return 2
  _git_grove_clamp "--at's user"    "$user"      'A-Za-z0-9._-' '[A-Za-z0-9._-]' || return 2
  _git_grove_clamp "--at's host"    "$host"      'A-Za-z0-9._-' '[A-Za-z0-9._-]' || return 2
  _git_grove_clamp "--at's port"    "$port"      '0-9'          '[0-9]'          || return 2
  _git_grove_clamp "--exid"         "$exid"      'A-Za-z0-9._-' '[A-Za-z0-9._-]' || return 2
  _git_grove_clamp "--env"          "$env"       'A-Za-z0-9._-' '[A-Za-z0-9._-]' || return 2
  _git_grove_clamp "--account"      "$account"   '0-9'          '[0-9] (a 12-digit aws account)' || return 2
  _git_grove_clamp "--nat"          "$nat"       'A-Za-z0-9._-' '[A-Za-z0-9._-]' || return 2

  # the cloud fields (exid, env, account, nat) are what let `git grove wake` be
  # portable: it finds the box by exid TAG and pins the account per grove, so one
  # skill wakes a grove in any account without a constant baked into it
  #
  # 🛑 .why `jq -n --arg`, and never a heredoc
  #      a heredoc writes `"name": "$name"` and eight more like it, so a `"` in
  #      ANY value forges a key. jq takes the LAST duplicate, and `host` and
  #      `user` are what `git grove wake` turns into ssh_config directives — so
  #      a forged pair overrides the address the human typed. `--arg` makes each
  #      value DATA that jq escapes; no value can become STRUCTURE, whatever
  #      bytes it holds (`rule.require.solve-at-cause`).
  #
  #      ⚠️ the clamp above already refuses a `"`. this is the SECOND half of
  #         one repair, on purpose: a grammar states what a value may be, and
  #         `--arg` makes the composer indifferent to what it turns out to be.
  #         either half alone is one edit away from broken.
  #
  # ⚠️ .an absent value is a JSON null, never the STRING "null"
  #      readers take the default off a real null — `jq -r '.user // "ec2-user"'`
  #      — and wake's `[[ "$USER_NAME" == "null" ]]` guard catches a literal too
  #
  # ⚠️ .the write is ATOMIC — a temp file, then a rename
  #      a `cat >` truncates before it composes, so an interrupted write left a
  #      registry that names a grove and holds none of its address
  #      (`gotcha.a-partial-write-discards-what-it-never-read`)
  if ! jq -n \
    --arg name "$name" \
    --arg sshAlias "$ssh_alias" \
    --arg user "$user" \
    --arg host "$host" \
    --arg port "$port" \
    --arg exid "${exid:-$name}" \
    --arg env "$env" \
    --arg account "$account" \
    --arg nat "$nat" \
    --argjson addedAt "$added_at" \
    '{
      name:     $name,
      sshAlias: $sshAlias,
      user:     (if $user    == "" then null else $user    end),
      host:     (if $host    == "" then null else $host    end),
      port:     (if $port    == "" then null else ($port | tonumber) end),
      exid:     $exid,
      env:      (if $env     == "" then null else $env     end),
      account:  (if $account == "" then null else $account end),
      nat:      (if $nat     == "" then null else $nat     end),
      type:     "ec2",
      status:   "active",
      addedAt:  $addedAt
    }' > "$dir/$name.json.tmp"; then
    rm -f "$dir/$name.json.tmp"
    echo "💥 could not compose the registry record for grove '$name'" >&2
    return 1
  fi
  if ! mv "$dir/$name.json.tmp" "$dir/$name.json"; then
    rm -f "$dir/$name.json.tmp"
    echo "💥 could not commit the registry record for grove '$name'" >&2
    return 1
  fi

  # when --alias names an ssh Host we do NOT own, never touch ~/.ssh/config
  if [[ -n "$alias" ]]; then
    echo "🌲 grove '$name' registered → ssh alias '$ssh_alias' (ssh config untouched)"
    return 0
  fi

  # an exid-only registration has no address yet — `git grove wake` derives it by
  # tag and writes the Host block once the tunnel's port is known. to write one
  # here would emit an empty HostName/Port that ssh cannot use
  if [[ -z "$at" ]]; then
    echo "🌲 grove '$name' registered → exid '${exid:-$name}'${env:+ in $env}${account:+ (account $account)}"
    echo "   └─ wake it to open its duct: git grove wake $name"
    return 0
  fi

  # else findsert our own Host block, so the alias carries the port
  # (ductwork rides plain 'ssh <alias>')
  local sshcfg="$HOME/.ssh/config"
  mkdir -p "$HOME/.ssh"; touch "$sshcfg"
  if ! grep -q "^Host $ssh_alias\$" "$sshcfg" 2>/dev/null; then
    {
      echo ""
      echo "Host $ssh_alias"
      echo "  HostName $host"
      echo "  Port $port"
      echo "  User $user"
      # ⚠️ the keepalive is what stops the SSM tunnel from expiry under an idle
      #    session. `git grove wake` reaches the box through `aws ssm
      #    start-session` with the port-forward document, so `ssh <alias>` rides a
      #    LOCAL port that session-manager-plugin relays. session manager applies
      #    its own `idleSessionTimeout` (default 20m) and counts SILENCE as idle —
      #    so an ssh session that sends no bytes is what makes SSM end the session,
      #    which drops the port, which kills the ssh.
      #    the human then sees "the connection died" with no error and no cause,
      #    and it looks like the box slept (it did not: 1.2.power sets
      #    IdleAction=ignore and AllowHibernation=no, and no timer stops a grove).
      #    60s of traffic keeps the channel non-idle; 3 misses ends a truly dead one
      echo "  ServerAliveInterval 60"
      echo "  ServerAliveCountMax 3"
      echo "  TCPKeepAlive yes"
    } >> "$sshcfg"
    echo "🌲 grove '$name' registered (+ ssh alias '$ssh_alias') → $user@$host:$port"
  else
    echo "🌲 grove '$name' registered (ssh alias '$ssh_alias' already present) → $user@$host:$port"
  fi
}

# .what: list registered groves
_git_grove_list() {
  local dir; dir="$(_git_grove_dir)"
  if [[ ! -d "$dir" ]] || [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
    echo "🌲 forest — no groves registered"
    echo "   └─ register one: git grove set <name> --at <user@host:port>"
    return 0
  fi
  echo "🌲 forest"
  local f
  # ⚠️ `find`, not a bare glob — this file is read by zsh too, where a glob
  #    that matches no file is a HARD ERROR that aborts the whole function.
  #    the `ls -A` guard above proves the dir is NON-EMPTY, which is NOT the
  #    same claim: a dir that holds only a stray non-json file passes that
  #    guard and still matches zero `.json`
  #    (`rule.forbid.bare-globs-in-dual-shell-files`)
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    local n a u h p
    n="$(jq -r '.name' "$f")"
    a="$(jq -r '.sshAlias // .name' "$f")"
    u="$(jq -r '.user' "$f")"
    h="$(jq -r '.host' "$f")"
    p="$(jq -r '.port' "$f")"
    if [[ "$h" == "null" ]]; then
      echo "   ├─ 🌳 $n → ssh:$a"
    else
      echo "   ├─ 🌳 $n → $u@$h:$p (ssh:$a)"
    fi
  done < <(find "$dir" -maxdepth 1 -type f -name '*.json' 2>/dev/null | sort)
}

# .what: the ssh alias to reach a grove by name
_git_grove_ssh_alias() {
  local name="${1:-}"
  local f; f="$(_git_grove_dir)/$name.json"
  [[ -f "$f" ]] || return 1
  jq -r '.sshAlias // .name' "$f"
}

# .what: show one grove
_git_grove_get() {
  local name="${1:-}"
  local f; f="$(_git_grove_dir)/$name.json"
  if [[ -z "$name" || ! -f "$f" ]]; then
    echo "✋ grove '$name' not found — run 'git grove list'" >&2
    return 2
  fi
  jq . "$f"
}

######################################################################
# .what = drop every registry entry whose cloud instance no longer exists
#
# 🛑 .why THE ANSWER IS THREE-VALUED, and the third arm is the whole design
#
#      a sweep asks aws "does this instance exist?" and that question has
#      three answers, not two:
#
#        found            → keep
#        absent, ASKED    → orphan, droppable
#        could not ask    → NO VERDICT — halt, and drop no entry
#
#      the third arm is what a two-valued sweep folds into the second, and
#      the cost is total: a camp credential lapses about hourly, so a sweep
#      that reads "the rack is locked" as "the instance is gone" DELETES THE
#      WHOLE FOREST, silently, and prints a clean page while it does.
#      (`gotcha.the-duct-returns-the-send-not-the-answer`, the reserved 97;
#       `gotcha.a-check-that-cries-wolf-gets-silenced`, q12.)
#
# 🛑 .why it queries `exid=` and never `Name=` — MEASURED 2026-09-02
#
#      these instances carry NO `Name` tag. a hand sweep asked `Name=<grove>`
#      and got "no instance matched" for `grove-ahbode-v20260811` — a box that
#      had been booted, pushed to, and run against minutes earlier.
#
#      ⚠️ the verdict was not merely wrong, it was wrong in the DELETE
#         direction and for every entry at once: a `--orphaned` built on that
#         key would have dropped the entire registry on its first run, with
#         each row reading exactly like a true orphan.
#
#      ⇒ so the tag key is not guessed here. it is READ FROM THE ENTRY —
#        `.exid` — which is the same addressing `git.grove.wake` resolves by,
#        so one fact has one holder (`term=holder`).
#
# ⚠️ .the FLOOR, for the blindness this cannot otherwise see
#      a reader blind in some NEW way would report every grove absent, and
#      each row would look right. so when every cloud entry reads absent and
#      there is more than one, this halts: an empty forest is possible, and a
#      blind reader is likelier, and only a human can tell them apart
#      (`term=floor` — a floor detects, it does not attribute).
#
# ⚠️ .why it asserts it RECOGNIZED the reply
#      found-vs-absent is read out of `aws.ec2.get`'s printed text, which is a
#      dependency on another component's FORMAT — invisible in any argument,
#      and free to break in silence the day that text moves. so a reply
#      matching NEITHER shape is a fourth no-verdict arm rather than a
#      fallthrough, and the sweep halts instead of a guess.
#
# usage:
#   git grove del --orphaned                # plan (default) — names what it would drop
#   git grove del --orphaned --mode apply   # drops them
######################################################################
_git_grove_del_orphaned() {
  local mode="plan"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode) mode="${2:-}"; shift 2 ;;
      --) shift ;;
      *) echo "✋ unknown flag '$1' — usage: git grove del --orphaned [--mode plan|apply]" >&2; return 2 ;;
    esac
  done
  case "$mode" in
    plan|apply) ;;
    *) echo "✋ --mode takes 'plan' or 'apply', not '$mode'" >&2; return 2 ;;
  esac

  if ! command -v rhx &>/dev/null; then
    echo "✋ rhx is absent, so the ec2 reader cannot be reached" >&2
    echo "   ⇒ no verdict is claimed about any grove; none was dropped" >&2
    return 2
  fi

  local dir; dir="$(_git_grove_dir)"
  if [[ ! -d "$dir" ]] || [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
    echo "🌲 forest — no groves registered, so no sweep is owed"
    return 0
  fi

  echo "🧹 git grove del --orphaned --mode $mode"
  echo "   └─ ask aws whether each cloud grove's instance still exists"
  echo ""

  local orphans=() cloud=0 f
  # 🛑 `find`, not a bare glob — and here the stake is a DELETE path.
  #    zsh reads this file too, and there a glob that matches no file is a
  #    HARD ERROR that aborts the whole function. the `[[ -f ]]` guard below
  #    reads as the defense and is never reached, which is the exact shape
  #    `rule.forbid.bare-globs-in-dual-shell-files` grades a blocker:
  #    *"a `[[ -f "$f" ]] || continue` guard presented as the defense for one
  #    = blocker (it cannot fire; it makes the defect look handled)"*.
  #
  # ⚠️ that abort fails CLOSED — the sweep drops no entry — so it is a
  #    correctness defect, not a vulnerability. closed anyway: a rule with
  #    live instances is a rule nobody enforces.
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    local n x e t
    n="$(jq -r '.name' "$f")"
    x="$(jq -r '.exid // empty' "$f")"
    e="$(jq -r '.env // "camp"' "$f")"
    t="$(jq -r '.type // empty' "$f")"

    # a grove registered by --at alone has no cloud instance to ask about, so
    # no verdict is possible. it is SKIPPED, never swept — an entry this reader
    # cannot judge is not an entry it may delete
    if [[ "$t" != "ec2" || -z "$x" ]]; then
      echo "   · $n — not a cloud grove, so no verdict is possible; skipped"
      continue
    fi
    cloud=$(( cloud + 1 ))

    local out rc=0
    out="$(rhx aws.ec2.get --tag "exid=$x" --env "$e" --state all 2>&1)" || rc=$?

    if [[ "$rc" -ne 0 ]]; then
      echo "   ✋ $n — the reader could not ask aws" >&2
      echo "      ⇒ that says NO WORD about the instance, so this halts here" >&2
      echo "        and drops no entry at all" >&2
      echo "" >&2
      printf '%s\n' "$out" | tail -8 >&2
      return 1
    fi

    if [[ "$out" == *"no instance matched"* ]]; then
      echo "   🫧 $n — asked aws, and no instance carries exid=$x"
      orphans+=("$n")
    elif [[ "$out" == *"found:"* ]]; then
      echo "   ✔ $n — the instance exists; kept"
    else
      # the reply matched neither shape. the reader's output moved, and a guess
      # here is a guess in the DELETE direction
      echo "   ✋ $n — the reply matched neither 'found:' nor 'no instance matched'" >&2
      echo "      ⇒ its output format moved, so this halts rather than lean" >&2
      echo "        one way on an answer it cannot read" >&2
      return 1
    fi
  done < <(find "$dir" -maxdepth 1 -type f -name '*.json' 2>/dev/null | sort)

  echo ""

  if [[ "${#orphans[@]}" -eq 0 ]]; then
    echo "🌲 every registered grove has a live instance ✔"
    return 0
  fi

  # ⚠️ THE FLOOR. every cloud entry absent is possible and unlikely; a reader
  #    blind in a new way produces exactly this page
  if [[ "${#orphans[@]}" -eq "$cloud" && "$cloud" -gt 1 ]]; then
    echo "   ✋ all $cloud cloud groves read as absent" >&2
    echo "      ⇒ an empty forest is possible; a blind reader is likelier, and" >&2
    echo "        this cannot tell them apart. so it drops none" >&2
    echo "      confirm ONE by hand, then re-run:" >&2
    echo "        rhx aws.ec2.get --tag exid=${orphans[0]} --state all" >&2
    return 1
  fi

  if [[ "$mode" == "plan" ]]; then
    echo "🐢 heres the wave — ${#orphans[@]} orphaned entr(ies) would be dropped:"
    local o; for o in "${orphans[@]}"; do echo "   ├─ $o"; done
    echo "   └─ run with --mode apply to drop them"
    return 0
  fi

  local rc=0 o
  for o in "${orphans[@]}"; do
    _git_grove_del "$o" || rc=1
  done
  return "$rc"
}

# .what: unregister a grove — drop registry json + ssh config Host block
_git_grove_del() {
  # `--orphaned` sweeps a DISCOVERED set; a bare name drops ONE. both end at
  # the same delete below, so the ssh-block strip has a single holder
  if [[ "${1:-}" == "--orphaned" ]]; then
    shift
    _git_grove_del_orphaned "$@"
    return $?
  fi

  local name="${1:-}"
  local f; f="$(_git_grove_dir)/$name.json"
  if [[ -z "$name" || ! -f "$f" ]]; then
    echo "✋ grove '$name' not found" >&2
    return 2
  fi
  # only strip an ssh Host block we wrote ourselves (host recorded => we owned it)
  local owned_alias=""
  if [[ "$(jq -r '.host' "$f")" != "null" ]]; then
    owned_alias="$(jq -r '.sshAlias // .name' "$f")"
  fi
  rm -f "$f"
  if [[ -n "$owned_alias" ]]; then
    local sshcfg="$HOME/.ssh/config"
    ####################################################################
    # 🛑 the alias is DATA here, never part of a program
    #
    # .why  = `sed -i "/^Host $owned_alias\$/,/^\$/d"` splices the alias — a
    #         value off a JSON file — into a sed ADDRESS. a `/` in it ends that
    #         address, and whatever follows is a sed COMMAND, run with `-i`
    #         against the human's `~/.ssh/config`. so a registry entry rewrites
    #         that file at will, and `ProxyCommand` there is a command this
    #         laptop runs on every later ssh.
    #
    #         `awk -v a=…` passes the alias as a VARIABLE, compared with `==`.
    #         there is no byte in it that awk reads as syntax
    #         (`rule.require.solve-at-cause`).
    #
    # ⚠️ this is the SAME block-strip `git.grove.wake` already does when it
    #    replaces a drifted alias (`git.grove.wake.sh`, the [REPLACE] arm), and
    #    it is deliberately the same three lines — one idiom for one job, so a
    #    reader who learns it once reads both
    #    (`rule.forbid.two-writers-on-one-artifact`).
    #
    # ⚠️ `grep -qxF` — `-x` whole line, `-F` fixed string. the guard must not be
    #    a second place where the alias is read as a pattern
    ####################################################################
    if [[ -f "$sshcfg" ]] && grep -qxF "Host $owned_alias" "$sshcfg"; then
      if awk -v a="Host $owned_alias" '
        $0 == a  { inblock = 1; next }
        /^Host /  { inblock = 0 }
        !inblock  { print }
      ' "$sshcfg" > "$sshcfg.del.tmp"; then
        mv "$sshcfg.del.tmp" "$sshcfg"
      else
        rm -f "$sshcfg.del.tmp"
        echo "✋ grove '$name' unregistered, but $sshcfg still holds its Host block" >&2
        echo "   ⇒ every ssh to '$owned_alias' keeps a block that names a port" >&2
        echo "     no tunnel serves any more" >&2
        echo "   fix: drop the 'Host $owned_alias' block by hand" >&2
        return 1
      fi
    fi
  fi
  echo "🍃 grove '$name' unregistered"
}

# .what: the duct URI that reaches a grove's default duct
#
# .why  = one address, ONE holder. spelled at each call site (`"$alias:main"`
#         in send ×2 and read) it drifts — a rename touches three sites and
#         forgets the fourth. it lives here once.
#
#         the NAME follows ductwork's own declared session grammar,
#         `<tree>/<role>` — the shape its registry code already anticipates
#         ("session may contain a slash (e.g. treename/role)") and the shape
#         termwork ships locally (`worktree/mechanic`, via `--for <role>`).
#
#         a bare `main` is wrong twice over:
#           - it names no role, though the duct IS a mechanic by default
#           - it collides with `main` the trunk (term=main), so one word means
#             a branch/checkout in one breath and a tmux session in the next
#
#         the tree segment stays `main` and that is not the same collision: a
#         grove's src sits in the MAIN CHECKOUT, so `main/mechanic` reads
#         exactly as the glossary defines it — the mechanic role, in the main
#         checkout. the term is used here, not overloaded.
#
# .note = the role is fixed at `mechanic` on purpose. termwork picks a role with
#         `--for <role>`, but `--for` is already taken on the provision commands
#         for machine-KIND (`--for local|cloud`), so to add it here would mint
#         the very overload this URI avoids. a second role on a grove wants
#         its own flag word, chosen deliberately — see the open dispute in
#         term=main._.choice.reason.md
_git_grove_duct_uri() {
  local alias="${1:-}"
  echo "duct://$alias/main/mechanic"
}

# .what: run a command in the grove's duct (findsert the session, then send)
_git_grove_send() {
  local name="${1:-}"; shift 2>/dev/null || true
  local what=""
  local rest=()
  # .the catch-all FORWARDS; it must never drop.
  #
  # a `*) shift ;;` catch-all silently discards every flag this loop does not
  # itself know. `--await 600` vanishes here, `duct.send` runs with no await
  # and refuses instantly, and the caller sees a guard that "ignored" its
  # flag. a wrapper that eats an unknown flag is a failhide: it reports
  # success for a request it never made (rule.forbid.failhide).
  #
  # forwarded instead, so `duct.send` — which owns this vocabulary — is the one
  # that accepts or rejects. an unknown flag fails LOUD, at the layer that can
  # name it (rule.require.failloud, rule.require.solve-at-cause)
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --what) what="$2"; shift 2 ;;
      *) rest+=("$1"); shift ;;
    esac
  done
  if [[ -z "$name" || -z "$what" ]]; then
    echo "✋ usage: git grove send <name> --what \"<cmd>\" [--await <secs>] [--anyway]" >&2
    return 2
  fi
  local alias; alias="$(_git_grove_ssh_alias "$name")" || {
    echo "✋ grove '$name' not found — run 'git grove list'" >&2; return 2;
  }
  local uri; uri="$(_git_grove_duct_uri "$alias")"
  duct.open --on "$uri" >/dev/null
  duct.send --on "$uri" --what "$what" "${rest[@]}"
}

# .what: read the grove's duct output
_git_grove_read() {
  local name="${1:-}"; shift 2>/dev/null || true
  if [[ -z "$name" ]]; then
    echo "✋ usage: git grove read <name> [--lines <n>]" >&2
    return 2
  fi
  local alias; alias="$(_git_grove_ssh_alias "$name")" || {
    echo "✋ grove '$name' not found — run 'git grove list'" >&2; return 2;
  }
  # forward the rest, same reason as _git_grove_send: a wrapper that reads only
  # the name and drops each arg after it keeps `--lines 40` from ever reaching
  # `duct.read`, so every read dumps the full 500-line default
  duct.read --on "$(_git_grove_duct_uri "$alias")" "$@"
}

git_alias_grab() {
  local cmd="${1:-get}"
  shift 2>/dev/null || true

  case "$cmd" in
    -h|--help)
      echo "git grab - save and transfer patches between worktrees"
      echo ""
      echo "usage: git grab <command> [options]"
      echo ""
      echo "commands:"
      echo "  set <name>  save changes as a patch"
      echo "  get         list patches, or get <name> [--mode apply]"
      echo "  del <name>  delete a patch"
      echo ""
      echo "run 'git grab <command> --help' for command-specific options"
      return 0
      ;;
    set) _git_grab_set "$@" ;;
    get) _git_grab_get "$@" ;;
    del) _git_grab_del "$@" ;;
    *)
      echo "error: unknown command '$cmd'"
      echo "run 'git grab --help' for usage"
      return 1
      ;;
  esac
}

# .what: save changes as a patch
_git_grab_set() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "git grab set - save changes as a patch"
    echo ""
    echo "usage: git grab set <name> [options]"
    echo ""
    echo "options:"
    echo "  --scope staged    save only staged changes"
    echo "  --scope unstaged  save only unstaged changes"
    echo "  --scope both      save staged and unstaged (default)"
    echo ""
    echo "behavior:"
    echo "  - fails if patch with same name already exists"
    echo "  - fails if no changes to save"
    return 0
  fi

  local name="" scope="both"

  # parse args
  local prev=""
  for arg in "$@"; do
    if [[ "$prev" == "--scope" ]]; then
      scope="$arg"
      prev=""
      continue
    fi
    case "$arg" in
      --scope) prev="--scope" ;;
      -*) ;;
      *) [[ -z "$name" ]] && name="$arg" ;;
    esac
  done

  if [[ -z "$name" ]]; then
    echo "error: patch name required"
    echo "usage: git grab set <name> [--scope staged|unstaged|both]"
    return 1
  fi

  # validate scope
  if [[ "$scope" != "staged" && "$scope" != "unstaged" && "$scope" != "both" ]]; then
    echo "error: invalid scope '$scope'"
    echo "valid scopes: staged, unstaged, both"
    return 1
  fi

  local patches_dir patch_file
  patches_dir="$(_git_grab_patches_dir)"
  patch_file="$patches_dir/$name.patch"

  # fail if patch exists
  if [[ -f "$patch_file" ]]; then
    echo "error: patch '$name' already exists"
    echo "use 'git grab del $name' to remove it first"
    return 1
  fi

  # check for changes
  local has_staged has_unstaged has_untracked
  has_staged=$(git diff --cached --quiet 2>/dev/null; echo $?)
  has_unstaged=$(git diff --quiet 2>/dev/null; echo $?)
  has_untracked=$(git ls-files --others --exclude-standard | head -1)

  case "$scope" in
    staged)
      if [[ "$has_staged" -eq 0 ]]; then
        echo "error: no staged changes to save"
        return 1
      fi
      ;;
    unstaged)
      if [[ "$has_unstaged" -eq 0 && -z "$has_untracked" ]]; then
        echo "error: no unstaged changes to save"
        return 1
      fi
      ;;
    both)
      if [[ "$has_staged" -eq 0 && "$has_unstaged" -eq 0 && -z "$has_untracked" ]]; then
        echo "error: no changes to save"
        return 1
      fi
      ;;
  esac

  # create patches directory
  mkdir -p "$patches_dir"

  # temporarily mark untracked files via intent-to-add so git diff sees them
  local untracked_files=()
  if [[ "$scope" != "staged" && -n "$has_untracked" ]]; then
    while IFS= read -r f; do
      untracked_files+=("$f")
    done < <(git ls-files --others --exclude-standard)
    git add -N "${untracked_files[@]}"
  fi

  # generate patch
  local patch_content=""
  case "$scope" in
    staged)
      patch_content=$(git diff --cached)
      ;;
    unstaged)
      patch_content=$(git diff)
      ;;
    both)
      # combine staged and unstaged into one patch
      patch_content=$(git diff HEAD)
      ;;
  esac

  # undo intent-to-add so untracked files go back to untracked
  if [[ ${#untracked_files[@]} -gt 0 ]]; then
    git reset -- "${untracked_files[@]}" >/dev/null 2>&1
  fi

  if [[ -z "$patch_content" ]]; then
    echo "error: no diff content generated"
    return 1
  fi

  echo "$patch_content" > "$patch_file"

  # count files affected
  local file_count
  file_count=$(echo "$patch_content" | grep -c '^diff --git' || echo 0)

  echo ""
  echo "🫐 $name"
  echo "   ├─ status: picked"
  echo "   ├─ scope: $scope"
  echo "   ├─ files: $file_count"
  echo "   └─ path: $patch_file"
  echo ""
}

# .what: list patches or apply a specific one
_git_grab_get() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "git grab get - list patches or apply one"
    echo ""
    echo "usage: git grab get [<name>] [options]"
    echo ""
    echo "options:"
    echo "  --mode plan    preview what would be applied (default)"
    echo "  --mode apply   apply and consume the patch"
    echo ""
    echo "behavior:"
    echo "  - without <name>: lists all available patches"
    echo "  - with <name>: previews the patch (plan mode)"
    echo "  - with <name> --mode apply: applies and deletes the patch"
    echo "  - uses git apply --3way for cross-branch support"
    return 0
  fi

  local patch_name="" mode="plan"

  # parse args
  local prev=""
  for arg in "$@"; do
    if [[ "$prev" == "--mode" ]]; then
      mode="$arg"
      prev=""
      continue
    fi
    case "$arg" in
      --mode) prev="--mode" ;;
      -*) ;;
      *) [[ -z "$patch_name" ]] && patch_name="$arg" ;;
    esac
  done

  local patches_dir
  patches_dir="$(_git_grab_patches_dir)"

  # if no patch specified, list available patches
  if [[ -z "$patch_name" ]]; then
    if [[ ! -d "$patches_dir" ]]; then
      echo ""
      echo "🧺 patches"
      echo "   └─ (empty)"
      echo ""
      return 0
    fi

    local patches=()
    # ⚠️ `find`, not a bare glob — an EMPTY patches dir is the NORMAL state,
    #    and this file is read by zsh, where a glob that matches no file is a
    #    hard error that aborts the function. the `[[ -f ]]` line below is the
    #    guard `rule.forbid.bare-globs-in-dual-shell-files` names verbatim as
    #    one that cannot fire and makes the defect look handled
    while IFS= read -r f; do
      [[ -f "$f" ]] || continue
      patches+=("$f")
    done < <(find "$patches_dir" -maxdepth 1 -type f -name '*.patch' 2>/dev/null | sort)

    echo ""
    echo "🧺 patches"

    if [[ ${#patches[@]} -eq 0 ]]; then
      echo "   └─ (empty)"
    else
      local i=0 count=${#patches[@]}
      for f in "${patches[@]}"; do
        ((i++))
        local name file_count
        name="$(basename "$f" .patch)"
        file_count=$(grep -c '^diff --git' "$f" 2>/dev/null || echo 0)
        if [[ $i -eq $count ]]; then
          echo "   └─ 🫐 $name ($file_count files)"
        else
          echo "   ├─ 🫐 $name ($file_count files)"
        fi
      done
    fi
    echo ""
    return 0
  fi

  # apply specific patch
  local patch_file="$patches_dir/$patch_name.patch"

  if [[ ! -f "$patch_file" ]]; then
    echo "error: patch '$patch_name' not found"
    echo "use 'git grab get' to list available patches"
    return 1
  fi

  # validate mode
  if [[ "$mode" != "plan" && "$mode" != "apply" ]]; then
    echo "error: invalid mode '$mode'"
    echo "valid modes: plan, apply"
    return 1
  fi

  local file_count
  file_count=$(grep -c '^diff --git' "$patch_file" 2>/dev/null || echo 0)

  # plan: preview what would be applied
  if [[ "$mode" == "plan" ]]; then
    echo ""
    echo "🫐 $patch_name (plan)"
    echo "   ├─ files: $file_count"
    echo "   └─ stats:"
    echo ""
    git apply --stat "$patch_file"
    echo ""
    echo -e "   \033[2muse --mode apply to apply\033[0m"
    return 0
  fi

  # apply the patch (try direct first, fall back to --3way for cross-branch)
  if ! git apply "$patch_file" 2>/dev/null; then
    if ! git apply --3way "$patch_file"; then
      echo ""
      echo "⛈️  patch did not apply cleanly"
      echo "   resolve conflicts, then 'git grab del $patch_name' to clean up"
      return 1
    fi
  fi

  # remove the patch after successful apply
  rm "$patch_file"

  echo ""
  echo "🫐 $patch_name"
  echo "   ├─ status: applied"
  echo "   ├─ files: $file_count"
  echo "   └─ patch consumed"
  echo ""
}

# .what: delete a patch
_git_grab_del() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "git grab del - delete a patch"
    echo ""
    echo "usage: git grab del <name>"
    echo ""
    echo "removes the patch file permanently"
    return 0
  fi

  local name="$1"

  if [[ -z "$name" ]]; then
    echo "error: patch name required"
    echo "usage: git grab del <name>"
    return 1
  fi

  local patches_dir patch_file
  patches_dir="$(_git_grab_patches_dir)"
  patch_file="$patches_dir/$name.patch"

  echo ""
  if [[ -f "$patch_file" ]]; then
    local file_count
    file_count=$(grep -c '^diff --git' "$patch_file" 2>/dev/null || echo 0)
    rm "$patch_file"
    echo "🫐 $name"
    echo "   ├─ status: discarded"
    echo "   └─ was: $file_count files"
  else
    echo "🫐 $name"
    echo "   └─ not found (no-op)"
  fi
  echo ""
}

######################
## usql secure wrapper
##
## what: wrapper for usql that adds --key flag for secure credential fetch
##
## why: credentials never exposed in process list or shell history
##      uses tmpfs (RAM) for ephemeral config, auto-cleanup on exit
##
## how:
##   usql --key POSTGRES_URL              # connect via keyrack secret
##   usql --key ATHENA_URL -c "SELECT 1"  # run query with keyrack secret
##   usql postgres://localhost/mydb       # regular usql (passthrough)
##
## setup:
##   1. install usql binary:
##      grove.provision --what 5.11.usql --mode apply
##
##   2. store database DSN in keyrack:
##      rhx keyrack set --key POSTGRES_URL --value 'postgres://user:pass@host:5432/db'
##
##   3. connect via wrapper:
##      usql --key POSTGRES_URL
##
## keyrack flow:
##   - wrapper calls `rhx keyrack get --key <KEY> --value` to fetch DSN
##   - DSN is written to an ephemeral config under $XDG_RUNTIME_DIR (tmpfs, RAM-only)
##   - usql reads config via XDG_CONFIG_HOME override
##   - config is deleted immediately after usql exits
##   - trap ensures cleanup even on ctrl+c or error
##
## security:
##   - DSN never appears in shell history (no inline password)
##   - DSN never visible in `ps aux` process list
##   - config exists only in RAM, never touches disk
##   - the dir is mktemp'd — an unguessable name, created 0700 atomically, so
##     no second seat on the box can pre-create or read it. see the block at
##     the mktemp call for why a $$-derived path in /dev/shm leaked it
##
## prereq: rhx keyrack must be configured with the key
######################

usql() {
  if [[ "$1" == "--key" ]]; then
    local key="$2"
    shift 2

    if [[ -z "$key" ]]; then
      echo "error: --key requires a keyrack key name"
      echo "usage: usql --key <KEY_NAME> [usql options]"
      return 1
    fi

    # 🛑 .why mktemp, and NEVER a path built from $$
    #    `/dev/shm/usql-$$` + `mkdir -p` + `chmod 700` leaks the DSN on a
    #    two-seat box for two reasons that compound:
    #
    #      1. the name is PREDICTABLE — /dev/shm is mode 1777, and a pid is a
    #         small integer any seat reads out of `ps`
    #      2. `mkdir -p` SUCCEEDS on a dir that already exists, and the `chmod`
    #         that follows fails silently when another seat owns it. so a seat
    #         that pre-creates the path receives the config.yaml write
    #
    #    mktemp closes both: it picks an unguessable name and creates the dir
    #    0700 ATOMICALLY, so there is no window to lose the race in
    #    (`rule.forbid.fixed-paths-in-a-shared-tmp`, `rule.prefer.prevent-over-correct`).
    #
    # ⚠️ $XDG_RUNTIME_DIR first — it is tmpfs AND already per-user 0700, so the
    #    RAM-only property holds and the dir is private by construction. /dev/shm
    #    is the fallback for a shell that has none (a bare `ssh host '<cmd>'`).
    local tmpbase="${XDG_RUNTIME_DIR:-/dev/shm}"
    local tmp
    tmp="$(mktemp -d "$tmpbase/usql-XXXXXXXXXX")" || {
      echo "✋ usql: could not create a private temp dir under $tmpbase" >&2
      return 1
    }
    trap 'rm -rf "$tmp"' EXIT

    # ⚠️ keyrack's stderr is NOT swallowed. `locked 🔒` and `absent 🫧` are BOTH
    #    rc=2 with empty stdout, so the exit code cannot tell them apart and only
    #    that stream can — and they want opposite repairs (`term=swallow`)
    local dsn
    dsn="$(rhx keyrack get --key "$key" --value)"
    if [[ -z "$dsn" ]]; then
      echo "✋ usql: keyrack returned no value for '$key' — its reason is above" >&2
      echo "   fix: rhx keyrack unlock --owner ehmpath --env <env>" >&2
      rm -rf "$tmp"
      return 1
    fi

    printf 'connections:\n  c: %s\n' "$dsn" > "$tmp/config.yaml"
    chmod 600 "$tmp/config.yaml"

    XDG_CONFIG_HOME="$tmp" command usql c "$@"
    local rc=$?

    rm -rf "$tmp"
    trap - EXIT
    return $rc
  else
    command usql "$@"
  fi
}

######################
## git backup (invoked by git alias.backup)
##
## what: backup all git repos and claude sessions to s3
##
## why: one command to backup all uncommitted work before risky situations
##      includes worktrees, staged/unstaged changes, and claude sessions
##
## how:
##   git backup --repo all --into s3://bucket/machine=name
##
## output structure:
##   s3://bucket/machine=name/effectiveAt=$timestamp/~/git.tar.gz
##   s3://bucket/machine=name/effectiveAt=$timestamp/~/.claude.tar.gz
##
## exclusions: node_modules/ and .cache/ dirs excluded from git.tar.gz
######################

# .what: append the members tar reported as changed mid-archive, and SAY when
#        it could not — never claim a patch that did not land
#
# .why: tar's `file changed as we read it` is PROSE, and GNU tar ESCAPES the
#       member name inside it. measured on tar 1.35, 2026-09-01, by a probe
#       that forced a real mid-read change on each name:
#
#         the name on disk     what tar printed     the regex recovers
#         ----------------     ----------------     ------------------
#         plain.bin            plain.bin            plain.bin           ✔
#         'a space.bin'        a space.bin          a space.bin         ✔
#         'a"quote.bin'        a"quote.bin          a"quote.bin         ✔
#         $'a\ttab.bin'        a\ttab.bin           a\ttab.bin          🛑
#         $'a\nnewline.bin'    a\nnewline.bin       a\nnewline.bin      🛑
#
#       the last two rows name NO FILE ON DISK — `\t` there is two literal
#       characters, not a tab. and this step reads ALL of `~/git`, into which a
#       `git.grove.pull` may land a remote tree: its boundary drops only `.git
#       node_modules .log .temp .agent/.cache` (`git.grove.operations.sh:141`),
#       so a grove picks which names this parse must survive.
#
# 🛑 .the failure hides TWICE, which is what makes it a false ✔
#    1. a count off the ARRAY prints `patch N changed files...` before a single
#       member is appended
#    2. `2>/dev/null` swallows tar's own words, and the exit code drops with it
#    ⇒ the backup reports success and uploads an archive short exactly the
#      files that changed — the files the patch exists to catch. that is
#      `rule.forbid.failhide`, on the one command a human runs when the work
#      is too precious to lose.
#
# ⚠️ .this does NOT try to reverse what tar escaped. a decoder is a second
#    grammar, free to drift from tar's, and a wrong decode is a name that
#    points at some OTHER file. it asks the DISK instead: a recovered name
#    either names a file or it does not, and one that does not is reported
#    verbatim, as tar printed it.
#
# ⚠️ .`--` before the operands is load-bear, and it costs MORE than one file.
#    the names arrive from tar's own output, so a name that leads with `-` is
#    spent on an option rather than a file (round 11: a boundary must not
#    consume what it bounds). measured 2026-09-01 with `-checkpoint-action`
#    among three operands:
#
#      tar: You may not specify more than one '-Acdtrux', '--delete' or
#           '--test-label' option
#
#    it parsed as the cluster `-c…`, `-c` collided with `-r`, and tar REFUSED
#    THE WHOLE INVOCATION — so ZERO of the three landed, including the one that
#    genuinely changed. one hostile name does not lose itself, it loses the
#    batch. the `-e` check below cannot catch that on its own, since a name
#    that leads with `-` may well exist; `--` is what settles it.
_git_backup_patch_changed() {   # $1 = archive, $2 = tar's stderr, $3.. = extra tar flags
  local archive="$1" stderr="$2"; shift 2
  local line name err rc=0
  local -a found=() unnamed=()

  ####################################################################
  # 🛑 NO `=~` CAPTURE HERE — THIS FILE IS SOURCED BY ZSH
  #
  # `~/.bash_aliases` is read by `~/.zshrc:204` into an INTERACTIVE ZSH, and
  # a human's `git backup` runs in that shell. bash and zsh both HAVE `[[ =~ ]]`
  # and they store the captures in different places:
  #
  #   | shell | the match lands in        | `${BASH_REMATCH[1]}` reads |
  #   | bash  | BASH_REMATCH[1]           | the name             ✔     |
  #   | zsh   | $match[1] / $MATCH        | EMPTY                🛑    |
  #
  # (zsh offers `setopt BASH_REMATCH`, and a file that needs an option set by
  #  its caller is a file with a hidden precondition — so it is not the fix.)
  #
  # 📜 .measured 2026-09-02 — and the defect was TOTAL, never partial
  #
  #   under zsh `name` is empty for every line, so `[[ -e "$HOME/$name" ]]`
  #   tests `$HOME/` — a directory, which always exists — and every changed
  #   member is appended to `found` as an EMPTY STRING. so:
  #
  #     · `unnamed` stays empty, so the ✋ that reports escaped names never fires
  #     · `found` fills with blanks, so `patched N changed files` prints N
  #     · tar is handed N empty operands instead of the N files
  #
  #   ⇒ the patch reported success and carried not one changed file — verbatim
  #     the `rule.forbid.failhide` defect the block above this function closes,
  #     reintroduced by the dialect of the shell it ships to.
  #
  # ⇒ the shape below uses `case` + parameter expansion, which are POSIX and
  #   read IDENTICALLY in both shells (`rule.forbid.bare-globs-in-dual-shell-files`
  #   names the same hazard for globs; this is its capture-variable twin).
  #
  # ⚠️ the two halves preserve the regex exactly:
  #     · `tar: *: file changed*` anchors both ends, as `^` did — a `case`
  #       pattern is tested against the WHOLE word
  #     · `%: file changed*` strips the SHORTEST suffix that fits, which keeps
  #       the LONGEST name — the greedy `(.+)` the regex had. a `%%` would take
  #       the shortest name and truncate any member whose own name holds the
  #       phrase `: file changed`
  #     · the `-n` test restores `(.+)`'s at-least-one-character demand, which
  #       `*` alone drops — and it is the guard that would have made this
  #       defect loud rather than silent
  ####################################################################
  while IFS= read -r line; do
    case "$line" in
      "tar: "*": file changed"*) ;;
      *) continue ;;
    esac
    name="${line#tar: }"
    name="${name%: file changed*}"
    [[ -n "$name" ]] || continue
    if [[ -e "$HOME/$name" ]]; then
      found+=("$name")
    else
      unnamed+=("$name")
    fi
  done <<< "$stderr"

  if [[ ${#unnamed[@]} -gt 0 ]]; then
    echo "   ├─ ✋ tar escaped ${#unnamed[@]} changed name(s), so they name no file on" >&2
    echo "   │     disk and are NOT patched into this archive:" >&2
    for name in "${unnamed[@]}"; do
      echo "   │     · $name" >&2
    done
    rc=1
  fi

  if [[ ${#found[@]} -gt 0 ]]; then
    if err="$(tar -rf "$archive" "$@" -C ~ -- "${found[@]}" 2>&1)"; then
      echo "   ├─ patched ${#found[@]} changed files"
    else
      echo "   ├─ ✋ the patch of ${#found[@]} changed file(s) FAILED — this archive is short" >&2
      [[ -n "$err" ]] && printf '   │     %s\n' "$err" >&2
      rc=1
    fi
  fi

  return "$rc"
}

# .what: main dispatcher for git backup
git_alias_backup() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "git backup - backup all git repos and claude sessions to s3"
    echo ""
    echo "usage: git backup --repo all --into <s3://bucket/machine=name>"
    echo ""
    echo "options:"
    echo "  --repo all     backup all repos in ~/git/ (required)"
    echo "  --into <uri>   s3 destination prefix (required)"
    echo ""
    echo "output structure:"
    echo "  <uri>/effectiveAt=<timestamp>/~/git.tar.gz"
    echo "  <uri>/effectiveAt=<timestamp>/~/.claude.tar.gz"
    echo ""
    echo "exclusions:"
    echo "  node_modules/ and .cache/ dirs excluded from git.tar.gz"
    return 0
  fi

  # check for pv (progress bar tool)
  if ! command -v pv &>/dev/null; then
    echo "⛈️  pv not found (needed for progress bars)"
    echo "   └─ install: sudo apt install pv"
    return 1
  fi

  local repo_target="" s3_prefix=""

  # parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo)
        repo_target="$2"
        shift 2
        ;;
      --into)
        s3_prefix="$2"
        shift 2
        ;;
      *)
        echo "error: unknown option '$1'"
        echo "usage: git backup --repo all --into <s3://bucket/machine=name>"
        return 1
        ;;
    esac
  done

  # validate --repo
  if [[ -z "$repo_target" ]]; then
    echo "error: --repo is required"
    echo "usage: git backup --repo all --into <s3://bucket/machine=name>"
    return 1
  fi

  if [[ "$repo_target" != "all" ]]; then
    echo "error: --repo must be 'all'"
    echo "usage: git backup --repo all --into <s3://bucket/machine=name>"
    return 1
  fi

  # validate --into
  if [[ -z "$s3_prefix" ]]; then
    echo "error: --into is required"
    echo "usage: git backup --repo all --into <s3://bucket/machine=name>"
    return 1
  fi

  if [[ ! "$s3_prefix" =~ ^s3:// ]]; then
    echo "error: --into must start with s3://"
    echo "usage: git backup --repo all --into <s3://bucket/machine=name>"
    return 1
  fi

  # validate ~/git/ exists
  if [[ ! -d ~/git ]]; then
    echo ""
    echo "⛈️  no git dir found"
    echo "   └─ ~/git/ does not exist"
    echo ""
    return 1
  fi

  # validate aws credentials upfront (fail fast, not after 30min of archive work)
  if ! aws sts get-caller-identity &>/dev/null; then
    echo ""
    echo "⛈️  aws credentials expired or not configured"
    echo "   └─ run: use.ahbode.prep"
    echo ""
    return 1
  fi

  # show tree status first
  _git_tree_status --repo @all

  # prepare timestamp and paths
  local timestamp s3_dest tmp_dir total_bytes tar_size gz_size
  local tar_stderr tar_stderr_file tar_exit git_size
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  s3_dest="${s3_prefix}/effectiveAt=${timestamp}/~"
  tmp_dir=$(mktemp -d)

  # === ~/git archive ===
  # get total size in bytes for pv progress bar
  total_bytes=$(du -sb ~/git --exclude='node_modules' --exclude='.cache' 2>/dev/null | cut -f1 || echo "0")
  tar_stderr_file=$(mktemp)

  # step 1: archive
  echo "📦 ~/git"
  tar -cf - \
    --exclude='node_modules' \
    --exclude='.cache' \
    -C ~ git 2>"$tar_stderr_file" | \
    pv -s "$total_bytes" -N $'   ├─ archive' > "$tmp_dir/git.tar"
  tar_exit=${PIPESTATUS[0]}
  tar_stderr=$(cat "$tar_stderr_file")
  rm -f "$tar_stderr_file"

  if [[ $tar_exit -gt 1 ]]; then
    echo "⛈️  failed to archive ~/git"
    rm -rf "$tmp_dir"
    return 1
  fi

  # patch if files changed mid-read
  if [[ $tar_exit -eq 1 && -n "$tar_stderr" ]]; then
    _git_backup_patch_changed "$tmp_dir/git.tar" "$tar_stderr" \
      --exclude='node_modules' \
      --exclude='.cache' || true
  fi

  # step 2: compress
  tar_size=$(stat -c%s "$tmp_dir/git.tar")
  pv -s "$tar_size" -N $'   └─ compress' < "$tmp_dir/git.tar" | gzip > "$tmp_dir/git.tar.gz"
  rm "$tmp_dir/git.tar"
  git_size=$(du -h "$tmp_dir/git.tar.gz" | cut -f1)

  # === ~/.claude archive ===
  local claude_size="" has_claude=false
  if [[ -d ~/.claude ]]; then
    total_bytes=$(du -sb ~/.claude 2>/dev/null | cut -f1 || echo "0")
    tar_stderr_file=$(mktemp)

    # step 1: archive
    echo "📦 ~/.claude"
    tar -cf - -C ~ .claude 2>"$tar_stderr_file" | \
      pv -s "$total_bytes" -N $'   ├─ archive' > "$tmp_dir/.claude.tar"
    tar_exit=${PIPESTATUS[0]}
    tar_stderr=$(cat "$tar_stderr_file")
    rm -f "$tar_stderr_file"

    if [[ $tar_exit -gt 1 ]]; then
      echo "⛈️  failed to archive ~/.claude"
      rm -rf "$tmp_dir"
      return 1
    fi

    # patch if files changed mid-read
    if [[ $tar_exit -eq 1 && -n "$tar_stderr" ]]; then
      _git_backup_patch_changed "$tmp_dir/.claude.tar" "$tar_stderr" || true
    fi

    # step 2: compress
    tar_size=$(stat -c%s "$tmp_dir/.claude.tar")
    pv -s "$tar_size" -N $'   └─ compress' < "$tmp_dir/.claude.tar" | gzip > "$tmp_dir/.claude.tar.gz"
    rm "$tmp_dir/.claude.tar"
    claude_size=$(du -h "$tmp_dir/.claude.tar.gz" | cut -f1)
    has_claude=true
  else
    echo "⚠️  ~/.claude/ not found, skipped"
  fi

  # === upload to s3 ===
  echo "☁️  upload"
  gz_size=$(stat -c%s "$tmp_dir/git.tar.gz")
  local git_tree_conn=$'└─'
  [[ "$has_claude" == "true" ]] && git_tree_conn=$'├─'
  if ! pv -s "$gz_size" -N "   $git_tree_conn git.tar.gz" < "$tmp_dir/git.tar.gz" | aws s3 cp - "$s3_dest/git.tar.gz"; then
    echo "⛈️  failed to upload git.tar.gz"
    rm -rf "$tmp_dir"
    return 1
  fi

  if [[ "$has_claude" == "true" ]]; then
    gz_size=$(stat -c%s "$tmp_dir/.claude.tar.gz")
    if ! pv -s "$gz_size" -N $'   └─ .claude.tar.gz' < "$tmp_dir/.claude.tar.gz" | aws s3 cp - "$s3_dest/.claude.tar.gz"; then
      echo "⛈️  failed to upload .claude.tar.gz"
      rm -rf "$tmp_dir"
      return 1
    fi
  fi

  # cleanup
  rm -rf "$tmp_dir"

  # show confirmation
  echo ""
  echo "🍯 got em"
  if [[ "$has_claude" == "true" ]]; then
    echo "   ├─ $s3_dest/git.tar.gz ($git_size)"
    echo "   └─ $s3_dest/.claude.tar.gz ($claude_size)"
  else
    echo "   └─ $s3_dest/git.tar.gz ($git_size)"
  fi
  echo ""
}

# ⚠️ this file MUST end with a newline. an absent one glues the last line to whatever follows,
#   and a prior incident killed the parse of ALL 4000+ lines that way — every alias in the file,
#   silently, from one edit at the tail (hazard.bash-aliases-parse-silently.md).
