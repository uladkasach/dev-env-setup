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

# make it easier to open the terminal
alias terminal='gnome-terminal & disown'

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
##   git release main             # check open release PR; if none, show latest tag status
##   git release main --apply     # check + enable automerge
##   git release main --retry     # check + rerun failed workflows
##
## output:
##   - shows version, CI status, and automerge state
##   - failed checks show the workflow name, url, and failing step
######################
git_alias_release() {
  local target="${1:-this}"
  local apply=false retry=false findsert=false
  [[ "$*" == *"--apply"* ]] && apply=true
  [[ "$*" == *"--retry"* ]] && retry=true
  [[ "$*" == *"--findsert"* ]] && findsert=true

  echo "" # headspace
  if [ "$target" = "main" ]; then
    _git_release_main "$apply" "$retry"
  else
    _git_release_this "$apply" "$retry" "$findsert"
  fi
  echo "" # headspace
}

# .what: check current branch's PR; if on main, delegate to _git_release_main
# .why:  convenient way to check PR status from any feature branch
_git_release_this() {
  local apply="$1" retry="$2" findsert="$3"
  local current_branch
  current_branch=$(git branch --show-current 2>/dev/null)

  # if on main/master, delegate to release main
  if [ "$current_branch" = "main" ] || [ "$current_branch" = "master" ] || [ -z "$current_branch" ]; then
    _git_release_main "$apply" "$retry"
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
        _git_release_pr "$pr_num" "$apply" "$retry"
      fi
    else
      echo -e "   ├─ \033[2mtry 'git release --findsert' to find or create pr\033[0m"
      echo -e "   └─ \033[2mtry 'git release main' to see latest release\033[0m"
    fi
    return 0
  fi

  _git_release_pr "$pr_num" "$apply" "$retry"
}

# .what: check open release PR; if none, show latest tag status
# .why:  see status of pending release or last completed release
_git_release_main() {
  local apply="$1" retry="$2"
  local pr_num
  pr_num=$(gh pr list --state open --json number,title | jq -r '.[] | select(.title | test("chore\\(release\\)")) | .number' | head -1)

  if [ -z "$pr_num" ]; then
    echo "🫧  no open release pr"
    git fetch origin --tags -q 2>/dev/null
    local latest_tag
    latest_tag=$(git tag --sort=-v:refname | head -1)

    if [ -n "$latest_tag" ]; then
      echo ""
      _git_release_tag_runs "$latest_tag" "$retry"
    fi
    return 0
  fi

  _git_release_pr "$pr_num" "$apply" "$retry"
}

# .what: check a specific PR's CI status and automerge state
# .why:  unified logic for displaying PR status, regardless of open/merged state
_git_release_pr() {
  local pr_num="$1" apply="$2" retry="$3"
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
  if [ "$failed" -gt 0 ]; then
    echo "⛈️  $failed check(s) failed"
    echo "$pr" | jq -r '.statusCheckRollup[] | select(.conclusion == "FAILURE") | [.name, (.detailsUrl // .targetUrl // "")] | @tsv' | while IFS=$'\t' read -r name url; do
      echo "  🔴 $name"
      local run_id err
      run_id=$(echo "$url" | sed -n 's/.*actions\/runs\/\([0-9]*\).*/\1/p')
      if [ -n "$run_id" ]; then
        err=$(gh run view "$run_id" --json jobs -q '.jobs[] | select(.conclusion == "failure") | (.steps[] | select(.conclusion == "failure") | .name) // .name' | head -1)
        echo "     ├─ $url"
        echo "     └─ ${err:-(see logs)}"
        if [ "$retry" = "true" ]; then
          gh run rerun "$run_id" --failed
          echo "     👌 rerun triggered"
        fi
      else
        echo "     └─ $url"
      fi
    done
    if [ "$retry" != "true" ]; then
      echo ""
      echo -e "   \033[2mhint: use --retry to rerun failed workflows\033[0m"
    fi
  elif [ "$pending" -gt 0 ]; then
    echo "   ├─ 🐢 $pending check(s) in progress"
  else
    echo "   ├─ 👌 all checks passed"
  fi

  # warn if branch is behind base
  if [ "$merge_state" = "BEHIND" ] && [ "$is_merged" != "true" ]; then
    echo "   ├─ 🐚 needs rebase" # shell: left behind on shore while the wave moves on
  fi

  # show automerge status
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
        echo "   └─ 🌴 automerge enabled [added]"
      fi
    else
      echo "   └─ 🌴 automerge unfound (use --apply to add)"
    fi
  else
    echo "   └─ 🌴 automerge enabled [found]"
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
    echo "⛈️  $tag_failed check(s) failed"
    echo "$tag_runs" | jq -r '.[] | select(.conclusion == "failure") | [.name, .url, .databaseId] | @tsv' | while IFS=$'\t' read -r name url run_id; do
      echo "  🔴 $name"
      local err
      err=$(gh run view "$run_id" --json jobs -q '.jobs[] | select(.conclusion == "failure") | (.steps[] | select(.conclusion == "failure") | .name) // .name' | head -1)
      echo "     ├─ $url"
      echo "     └─ ${err:-(see logs)}"
      if [ "$retry" = "true" ]; then
        gh run rerun "$run_id" --failed
        echo "     👌 rerun triggered"
      fi
    done
    if [ "$retry" != "true" ]; then
      echo ""
      echo "hint: use --retry to rerun failed workflows"
    fi
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

# .what: list worktrees for current repo
_git_tree_get() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "git tree get - list worktrees for current repo"
    echo ""
    echo "usage: git tree get"
    echo ""
    echo "lists all worktrees matching the current repo name"
    return 0
  fi

  local worktrees_dir repo_name
  worktrees_dir="$(_git_tree_worktrees_dir)"
  repo_name="$(_git_tree_repo_name)"

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
      local name branch commit_info
      name="$(basename "$dir")"
      branch="${name#$repo_name.}"
      commit_info=$(git -C "$dir" log -1 --format="%h %s" 2>/dev/null || echo "(unknown)")
      if [[ $i -eq $count ]]; then
        echo "   └─ 🌲 $branch"
        echo "       ├─ path: $dir"
        echo "       └─ head: $commit_info"
      else
        echo "   ├─ 🌲 $branch"
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
    echo "  --from main  create branch from origin/main"
    echo "  --from this  create branch from current HEAD"
    echo "  --open       open worktree in codium after creation"
    echo ""
    echo "behavior:"
    echo "  - if worktree exists: keeps it (idempotent)"
    echo "  - if local branch exists: adds worktree to it"
    echo "  - if remote branch exists: tracks and adds worktree"
    echo "  - otherwise: creates new branch from --from target"
    return 0
  fi

  local branch="" open_flag=false from_target=""

  # parse args
  local prev=""
  for arg in "$@"; do
    if [[ "$prev" == "--from" ]]; then
      from_target="$arg"
      prev=""
      continue
    fi
    case "$arg" in
      --open) open_flag=true ;;
      --from) prev="--from" ;;
      -*) ;;
      *) [[ -z "$branch" ]] && branch="$arg" ;;
    esac
  done

  if [[ -z "$branch" ]]; then
    echo "usage: git tree set <branch> --from <main|this> [--open]"
    return 1
  fi

  if [[ -z "$from_target" ]]; then
    echo "error: --from <main|this> is required"
    echo "usage: git tree set <branch> --from <main|this> [--open]"
    return 1
  fi

  if [[ "$from_target" != "main" && "$from_target" != "this" ]]; then
    echo "error: --from must be 'main' or 'this'"
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
    # get current commit info from existing worktree
    commit_info=$(git -C "$worktree_path" log -1 --format="%h %s" 2>/dev/null)
    sprouted_from=""
  else
    status="created"
    mkdir -p "$worktrees_dir"

    if git show-ref --verify --quiet "refs/heads/$branch"; then
      # local branch exists
      sprouted_from="$branch (existing)"
      git worktree add -q "$worktree_path" "$branch"
    elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
      # remote branch exists
      sprouted_from="origin/$branch"
      git worktree add -q --track -b "$branch" "$worktree_path" "origin/$branch"
    elif [[ "$from_target" == "main" ]]; then
      # create from origin/main (or origin/master)
      local base_ref="origin/main"
      git fetch origin main 2>/dev/null || base_ref="origin/master"
      sprouted_from="$base_ref"
      git worktree add -q -b "$branch" "$worktree_path" "$base_ref"
    else
      # create new branch from HEAD (--from this)
      sprouted_from=$(git branch --show-current)
      git worktree add -q -b "$branch" "$worktree_path"
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
  echo "   └─ head: $commit_info"
  echo ""

  # optionally open in editor
  if [[ "$open_flag" == "true" ]]; then
    codium "$worktree_path" &
  fi
}

# .what: remove worktree for branch
_git_tree_del() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "git tree del - remove worktree for branch"
    echo ""
    echo "usage: git tree del <branch>"
    echo ""
    echo "removes the worktree directory and prunes git references"
    echo "safe to run if worktree doesn't exist (no-op)"
    return 0
  fi

  local branch="$1"

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
    git worktree remove "$worktree_path" --force 2>/dev/null || {
      rm -rf "$worktree_path"
      git worktree prune
    }
    echo "🍂 $repo_name.$sanitized"
    echo "   ├─ status: removed"
    echo "   ├─ branch: $branch"
    echo "   └─ was at: $commit_info"
  else
    echo "🍂 $repo_name.$sanitized"
    echo "   └─ status: not found (no-op)"
  fi
  echo ""
}
