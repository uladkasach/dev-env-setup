# open notes
alias notes='vim ~/git/notes/main.txt'

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

# aws profiles
alias use.tugether='export AWS_PROFILE=tugether'
alias use.ahbode.dev='export AWS_PROFILE=ahbode.dev'
alias use.ahbode.prod='export AWS_PROFILE=ahbode.prod'
alias use.ahction='export AWS_PROFILE=ahction'
alias use.whodis.prod='export AWS_PROFILE=whodis.prod'
alias use.alistokrad.prod='export AWS_PROFILE=alistokrad.prod'

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
alias use.keymap.altswap='setxkbmap -option altwin:swap_lalt_lwin' # https://unix.stackexchange.com/a/367016/77522

# make signing into onepass easier
alias op.signin='eval $(op signin)'

# make it easier to open the browser
alias browser='google-chrome & disown'

# note: 'terminal' command installed via install_env.sh (supports 'terminal /path/to/dir')

# make it easier to open the file manager
alias files='nautilus & disown'

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

# make it easy to update shell configs
alias sync.devenv.bashaliases='cp ~/git/more/dev-env-setup/src/bash_aliases.sh ~/.bash_aliases && source ~/.bash_aliases'
alias sync.devenv.zshrc='cp ~/git/more/dev-env-setup/src/zshrc.sh ~/.zshrc && source ~/.zshrc'
alias sync.devenv='sync.devenv.bashaliases && sync.devenv.zshrc'

# make it easy to pull down the devenv repo
alias devenv.sync.repo='cd ~/git/more/dev-env-setup && git checkout main && git pull origin HEAD'

# make it easy to suspend and restart and shutdown
alias power.suspend='systemctl suspend' # todo, swap to `suspend-then-hibernate` when supported
alias power.off='shutdown -h now '
alias power.restart='reboot'

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
alias use.ahbode.dev.vpc='use.ahbode.dev && /home/vlad/.local/bin/use.vpc.tunnel'
alias use.ahbode.prod.vpc='use.ahbode.prod && /home/vlad/.local/bin/use.vpc.tunnel'

# smart npm: use npm if package-lock.json exists, otherwise pnpm
npm() {
  if [[ -f "package-lock.json" ]]; then
    npm_real "$@"
  else
    pnpm "$@"
  fi
}

# smart npx: prefer local bin, then npx/pnpm dlx based on lockfile
npx() {
  local cmd="$1"
  if [[ -n "$cmd" && -x "./node_modules/.bin/$cmd" ]]; then
    shift
    "./node_modules/.bin/$cmd" "$@"
  elif [[ -f "package-lock.json" ]]; then
    npx_real "$@"
  else
    pnpm dlx "$@"
  fi
}

# tsx: always resolve via smart npx (which routes to npx or pnpm dlx)
tsx() { npx tsx "$@"; }

# npm_real/npx_real for smart npm/npx wrappers (fnm setup is in .zshrc)
npm_real() { command npm "$@"; }
npx_real() { command npx "$@"; }


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
## git worktree helpers (invoked by git alias.tree)
##
## what: manage git worktrees with repo-prefixed directory names
##
## why: enables parallel work on branches without stashing/switching
##      repo prefix prevents collisions when working across multiple repos
##
## how:
##   git tree get                            # list worktrees for current repo
##   git tree set <branch> --from main|this  # create/find worktree for branch
##   git tree del <branch>                   # remove worktree for branch
##
## worktree location: @gitroot/../_worktrees/$reponame.$branch/
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
      echo ""
      echo "run 'git tree <command> --help' for command-specific options"
      return 0
      ;;
    get) _git_tree_get "$@" ;;
    set) _git_tree_set "$@" ;;
    del) _git_tree_del "$@" ;;
    *)
      echo "usage: git tree <get|set|del> [branch]"
      echo "run 'git tree --help' for more info"
      return 1
      ;;
  esac
}

# .what: list worktrees for current repo, or open a specific one
_git_tree_get() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "git tree get - list worktrees for current repo"
    echo ""
    echo "usage: git tree get [branch] [--open <opener>]"
    echo ""
    echo "options:"
    echo "  <branch>            show specific worktree (optional)"
    echo "  --open <opener>     open worktree with specified opener"
    echo "                      e.g., --open terminal, --open codium"
    echo ""
    echo "examples:"
    echo "  git tree get                        # list all worktrees"
    echo "  git tree get feat/foo               # show specific worktree"
    echo "  git tree get feat/foo --open codium # open in codium"
    return 0
  fi

  local branch="" opener=""

  # parse args
  local prev=""
  for arg in "$@"; do
    if [[ "$prev" == "--open" ]]; then
      opener="$arg"
      prev=""
      continue
    fi
    case "$arg" in
      --open) prev="--open" ;;
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
      echo -e "   └─ \033[2mtry 'git tree set $branch --from main|this' to create it\033[0m"
      return 1
    fi

    local commit_info
    commit_info=$(git -C "$worktree_path" log -1 --format="%h %s" 2>/dev/null || echo "(unknown)")

    echo ""
    echo "🌲 $repo_name.$sanitized"
    echo "   ├─ branch: $branch"
    echo "   ├─ path: $worktree_path"
    if [[ -n "$opener" ]]; then
      echo "   ├─ head: $commit_info"
      echo -e "   └─ \033[2mopen in $opener...\033[0m"
    else
      echo "   └─ head: $commit_info"
    fi
    echo ""

    # note: subshell ensures opener inherits correct cwd, without mutate of parent shell
    if [[ -n "$opener" ]]; then
      (cd "$worktree_path" && "$opener" .) &
    fi
    return 0
  fi

  # no branch specified: list all worktrees
  if [[ ! -d "$worktrees_dir" ]]; then
    echo ""
    echo "🌲 $repo_name"
    echo "   └─ (no worktrees)"
    echo ""
    return 0
  fi

  local found=0 count=0
  local branches=()
  for dir in "$worktrees_dir"/"$repo_name".*; do
    [[ -d "$dir" ]] || continue
    branches+=("$dir")
    ((count++))
  done

  echo ""
  echo "🏔️  $repo_name"

  if [[ $count -eq 0 ]]; then
    echo "   └─ (no worktrees)"
  else
    local i=0
    for dir in "${branches[@]}"; do
      ((i++))
      local name branch_name commit_info
      name="$(basename "$dir")"
      branch_name="${name#$repo_name.}"
      commit_info=$(git -C "$dir" log -1 --format="%h %s" 2>/dev/null || echo "(unknown)")
      if [[ $i -eq $count ]]; then
        echo "   └─ 🌲 $branch_name"
        echo "       ├─ path: $dir"
        echo "       └─ head: $commit_info"
      else
        echo "   ├─ 🌲 $branch_name"
        echo "   │  ├─ path: $dir"
        echo "   │  └─ head: $commit_info"
      fi
    done
  fi
  echo ""
}

# .what: create or find worktree for branch
_git_tree_set() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "git tree set - create or find worktree for branch"
    echo ""
    echo "usage: git tree set <branch> --from <main|this> [options]"
    echo ""
    echo "options:"
    echo "  --from main         create branch from origin/main"
    echo "  --from this         create branch from current HEAD"
    echo "  --open <opener>     open worktree with specified opener"
    echo "                      e.g., --open terminal, --open codium"
    echo "  --init              run pnpm install in background"
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
    echo "usage: git tree set <branch> --from <main|this> [--open <opener>]"
    return 1
  fi

  if [[ -z "$from_target" ]]; then
    echo "error: --from <main|this> is required"
    echo "usage: git tree set <branch> --from <main|this> [--open <opener>]"
    return 1
  fi

  if [[ "$from_target" != "main" && "$from_target" != "this" ]]; then
    echo "error: --from must be 'main' or 'this'"
    return 1
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

  local status sprouted_from commit_info

  # findsert: find or insert
  if [[ -d "$worktree_path" ]]; then
    status="found"
    # get current commit info from worktree found
    commit_info=$(git -C "$worktree_path" log -1 --format="%h %s" 2>/dev/null)
    sprouted_from=""
  else
    status="created"
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
      # create new branch from HEAD (--from this) with no upstream
      sprouted_from=$(git branch --show-current)
      git worktree add -q --no-track -b "$branch" "$worktree_path"
    fi
    commit_info=$(git -C "$worktree_path" log -1 --format="%h %s" 2>/dev/null)
  fi

  # viby output
  echo ""
  echo "🌲 $repo_name.$sanitized"
  echo "   ├─ status: $status"
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
  [[ "$init_flag" != "true" && -f "$worktree_path/package.json" ]] && lines+=("tip: use --init to run pnpm install in background")

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

  # kick off pnpm install in background if requested and package.json exists
  if [[ "$init_flag" == "true" && -f "$worktree_path/package.json" ]]; then
    (
      cd "$worktree_path" && \
      pnpm install --silent 2>/dev/null && \
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
    echo ""
    echo "options:"
    echo "  --this  delete current branch (with safety guards)"
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

  local branch="$1"
  local delete_branch=false

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
    return 1
  fi

  local repo_name worktrees_dir sanitized worktree_path
  repo_name="$(_git_tree_repo_name)"
  worktrees_dir="$(_git_tree_worktrees_dir)"
  sanitized="$(_git_tree_sanitize_branch "$branch")"
  worktree_path="$worktrees_dir/$repo_name.$sanitized"

  echo ""
  if [[ -d "$worktree_path" ]]; then
    local commit_info
    commit_info=$(git -C "$worktree_path" log -1 --format="%h %s" 2>/dev/null || echo "(unknown)")

    # ensure all files are deletable (pnpm, test runners, etc can create restricted permissions)
    chmod -R u+rwX "$worktree_path" 2>/dev/null || {
      echo "⚠️  cannot chmod worktree (permission denied without sudo)"
      echo "   └─ fix: sudo chmod -R u+rwX \"$worktree_path\""
      return 1
    }

    git worktree remove "$worktree_path" --force 2>/dev/null || {
      rm -rf "$worktree_path"
      git worktree prune
    }
    echo "🍂 $repo_name.$sanitized"
    echo "   ├─ status: removed"
    echo "   ├─ branch: $branch"
    if [[ "$delete_branch" == "true" ]]; then
      git branch -D "$branch" 2>/dev/null
      git push origin --delete "$branch" 2>/dev/null
      echo "   ├─ was at: $commit_info"
      echo "   └─ branch deleted (local + remote)"
    else
      echo "   └─ was at: $commit_info"
    fi
  else
    if [[ "$delete_branch" == "true" ]]; then
      # no worktree but still delete the branch
      git branch -D "$branch" 2>/dev/null
      git push origin --delete "$branch" 2>/dev/null
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

# .what: main entry for git graft
git_alias_graft() {
  local graft_state=".git/GRAFT_ORIG_HEAD"

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
      worktree_path=$(git worktree list --porcelain 2>/dev/null | grep -B2 "\[${branch}\]" | head -1 | sed 's/^worktree //')
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
    echo "  git graft --onto main --from abc123              # plan abc123..HEAD"
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
    info=$(git log -1 --format="%h %s" "$commit")
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
  worktree_path=$(git worktree list --porcelain 2>/dev/null | grep -B2 "\[${current_branch}\]" | head -1 | sed 's/^worktree //')
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
##   git grab set <name>                  # save both staged+unstaged changes
##   git grab set <name> --mode staged    # save only staged changes
##   git grab set <name> --mode unstaged  # save only unstaged changes
##   git grab get                         # list available patches
##   git grab get --patch <name>          # apply a specific patch
##   git grab del <name>                  # delete a patch
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
      echo "  get         list patches, or apply with --patch <name>"
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
    echo "  --mode staged    save only staged changes"
    echo "  --mode unstaged  save only unstaged changes"
    echo "  --mode both      save staged and unstaged (default)"
    echo ""
    echo "behavior:"
    echo "  - fails if patch with same name already exists"
    echo "  - fails if no changes to save"
    return 0
  fi

  local name="" mode="both"

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
      *) [[ -z "$name" ]] && name="$arg" ;;
    esac
  done

  if [[ -z "$name" ]]; then
    echo "error: patch name required"
    echo "usage: git grab set <name> [--mode staged|unstaged|both]"
    return 1
  fi

  # validate mode
  if [[ "$mode" != "staged" && "$mode" != "unstaged" && "$mode" != "both" ]]; then
    echo "error: invalid mode '$mode'"
    echo "valid modes: staged, unstaged, both"
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

  # check for changes based on mode
  local has_staged has_unstaged
  has_staged=$(git diff --cached --quiet 2>/dev/null; echo $?)
  has_unstaged=$(git diff --quiet 2>/dev/null; echo $?)

  case "$mode" in
    staged)
      if [[ "$has_staged" -eq 0 ]]; then
        echo "error: no staged changes to save"
        return 1
      fi
      ;;
    unstaged)
      if [[ "$has_unstaged" -eq 0 ]]; then
        echo "error: no unstaged changes to save"
        return 1
      fi
      ;;
    both)
      if [[ "$has_staged" -eq 0 && "$has_unstaged" -eq 0 ]]; then
        echo "error: no changes to save"
        return 1
      fi
      ;;
  esac

  # create patches directory
  mkdir -p "$patches_dir"

  # generate patch
  local patch_content=""
  case "$mode" in
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
  echo "   ├─ mode: $mode"
  echo "   ├─ files: $file_count"
  echo "   └─ path: $patch_file"
  echo ""
}

# .what: list patches or apply a specific one
_git_grab_get() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "git grab get - list patches or apply one"
    echo ""
    echo "usage: git grab get [options]"
    echo ""
    echo "options:"
    echo "  --patch <name>  select a patch"
    echo "  --plan          show what would be applied (requires --patch)"
    echo "  --apply         apply the patch (requires --patch)"
    echo ""
    echo "behavior:"
    echo "  - without --patch: lists all available patches"
    echo "  - with --patch --plan: shows diff stats"
    echo "  - with --patch --apply: applies and deletes the patch"
    echo "  - fails if patch doesn't apply cleanly"
    return 0
  fi

  local patch_name="" plan=false apply=false

  # parse args
  local prev=""
  for arg in "$@"; do
    if [[ "$prev" == "--patch" ]]; then
      patch_name="$arg"
      prev=""
      continue
    fi
    case "$arg" in
      --patch) prev="--patch" ;;
      --plan) plan=true ;;
      --apply) apply=true ;;
      -*) ;;
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
    for f in "$patches_dir"/*.patch; do
      [[ -f "$f" ]] || continue
      patches+=("$f")
    done

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

  # check if working tree is clean enough (no conflicts)
  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    # has changes, check if patch would conflict
    if ! git apply --check "$patch_file" 2>/dev/null; then
      echo "error: patch would not apply cleanly"
      echo "commit or stash your changes first"
      return 1
    fi
  else
    # clean tree, still verify patch applies
    if ! git apply --check "$patch_file" 2>/dev/null; then
      echo "error: patch would not apply cleanly"
      echo "the patch may be outdated or for a different branch"
      return 1
    fi
  fi

  local file_count
  file_count=$(grep -c '^diff --git' "$patch_file" 2>/dev/null || echo 0)

  if [[ "$plan" == "true" ]]; then
    echo ""
    echo "🫐 $patch_name (plan)"
    echo "   ├─ status: would apply cleanly"
    echo "   └─ files: $file_count"
    echo ""
    git apply --stat "$patch_file"
    return 0
  fi

  if [[ "$apply" != "true" ]]; then
    echo ""
    echo "🫐 $patch_name"
    echo "   ├─ status: ready"
    echo "   └─ files: $file_count"
    echo ""
    echo -e "   \033[2muse --plan to preview or --apply to apply\033[0m"
    return 0
  fi

  # apply the patch
  if ! git apply "$patch_file"; then
    echo "error: failed to apply patch"
    return 1
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
