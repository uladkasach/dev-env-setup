#!/usr/bin/env bash
######################################################################
# .what = test for termwork's --for / --tab / --duct logic
#
# .why  = termwork drives kitty + tmux, which spawn real windows and
#         sessions. two modes:
#           stub (default) — fakes kitty/tmux on PATH, asserts the pure
#             orchestration logic headless (arg parse, --for expansion,
#             base-vs-tab, registry writes, address-by-id).
#           live (--live)  — drives REAL tmux + kitty end-to-end: opens
#             a terminal, adds a role tab, sends markers to each role,
#             reads them back, and proves the two tabs attach different
#             sessions while the tab bar shows clean role titles.
#
# usage:
#   rhx termwork.test                 # stub checks (headless, safe)
#   rhx termwork.test live            # real kitty + tmux (pops windows)
#
# guarantee:
#   - stub: syntax + --for/--tab/--duct logic + back-compat
#   - live: real attach per role, title != session, tabs decoupled
#   - live cleans up its tmux sessions + kitty window on exit
#   - exit 0 = all pass, exit 1 = a check failed
######################################################################

set -uo pipefail

# mode: default stub (headless). any 'live'/'--live' arg selects live mode; any
# 'clean'/'--clean' arg reaps leftover twtest-* tmux sessions + kitty windows.
# (args scanned in any position since the rhx wrapper may reorder front flags.)
MODE="stub"
for _a in "$@"; do
  [[ "$_a" == "live"  || "$_a" == "--live"  ]] && MODE="live"
  [[ "$_a" == "clean" || "$_a" == "--clean" ]] && MODE="clean"
  [[ "$_a" == "demo"  || "$_a" == "--demo"  ]] && MODE="demo"
  [[ "$_a" == "tmuxcheck" || "$_a" == "--tmuxcheck" ]] && MODE="tmuxcheck"
  [[ "$_a" == "shellcheck" || "$_a" == "--shellcheck" ]] && MODE="shellcheck"
done

# ── shellcheck mode: does the REAL shell push @repo/@branch inside tmux? ──────
# .why = tmuxcheck sets @repo/@branch by hand; this proves the OTHER half — that
#        _set_terminal_title in zshrc actually pushes them. it launches a real
#        login zsh inside a tmux pane, cd's into this repo, waits for the precmd
#        hook to fire, then reads the pane options back. catches a broken/renamed
#        hook before a human ever reloads.
if [[ "$MODE" == "shellcheck" ]]; then
  echo "🐢 shell push check — does zsh feed tmux?"
  echo ""
  echo "🐚 termwork.test --shellcheck"
  spass=0; sfail=0
  sok()  { spass=$((spass+1)); echo "   ✅ $1"; }
  sbad() { sfail=$((sfail+1)); echo "   ⛈️  $1"; [[ -n "${2:-}" ]] && echo "        $2"; }
  for b in tmux zsh git; do
    command -v "$b" >/dev/null 2>&1 || { sbad "$b present" "not installed"; echo "   └─ result: pass $spass / fail $sfail"; exit 1; }
  done

  RROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && git rev-parse --show-toplevel 2>/dev/null)
  S="twdemo-shell-$$"
  tmux kill-session -t "$S" 2>/dev/null || true
  # launch a real login zsh in the pane, in this repo
  tmux new-session -d -s "$S" -x 120 -y 40 -c "$RROOT" "zsh -l"
  sleep 2
  # source the REPO copy of zshrc (the change may not be synced to ~/.zshrc yet);
  # this redefines _set_terminal_title + re-adds the precmd hook. then a fresh
  # prompt (via cd) fires the hook, which pushes @repo/@branch.
  echo "   ├─ sources repo src/zshrc.sh (tests the repo change, not ~/.zshrc)"
  tmux send-keys -t "$S" "source '$RROOT/src/zshrc.sh'" Enter
  sleep 1
  tmux send-keys -t "$S" "cd '$RROOT'" Enter
  sleep 1.5

  grepo=$(tmux show -p -t "$S" -v @repo 2>/dev/null)
  gbranch=$(tmux show -p -t "$S" -v @branch 2>/dev/null)
  echo "   ├─ @repo  = '$grepo'"
  echo "   ├─ @branch = '$gbranch'"
  [[ "$grepo" == "dev-env-setup" ]] && sok "zsh pushed @repo = dev-env-setup" || sbad "zsh pushed @repo" "got '$grepo'"
  [[ -n "$gbranch" ]] && sok "zsh pushed a non-empty @branch" || sbad "zsh pushed @branch" "empty"
  # branch must be clean — no subpath leaked in (the whole point of the shell push)
  [[ "$gbranch" != */src && "$gbranch" != *"/.agent"* ]] && sok "@branch has no subpath leak" || sbad "@branch subpath leak" "got '$gbranch'"

  tmux kill-session -t "$S" 2>/dev/null || true
  echo "   └─ result: pass $spass / fail $sfail"
  echo ""
  [[ "$sfail" -eq 0 ]] && { echo "🐢 shell yeah — zsh feeds tmux 🌊"; exit 0; } || { echo "🐢 bummer dude — $sfail failed"; exit 1; }
fi

# ── tmuxcheck mode: verify the tmux status-line reads @repo / @branch ─────────
# .why = the shell (_set_terminal_title in zshrc) pushes $repo + $branch to the
#        pane options @repo/@branch inside tmux; src/tmux.conf reads them in
#        status-left/right (no string parse). this sets those options on a real
#        pane and asserts the status format strings render them — so a rename or a
#        bad option ref is caught before a human reloads tmux.
if [[ "$MODE" == "tmuxcheck" ]]; then
  echo "🐢 tmux status check — read the footer..."
  echo ""
  echo "🐚 termwork.test --tmuxcheck"
  tpass=0; tfail=0
  tok()  { tpass=$((tpass+1)); echo "   ✅ $1"; }
  tbad() { tfail=$((tfail+1)); echo "   ⛈️  $1"; [[ -n "${2:-}" ]] && echo "        $2"; }
  if ! command -v tmux >/dev/null 2>&1; then tbad "tmux present" "not installed"; exit 1; fi

  echo "   ├─ tmux: $(tmux -V)"
  S="twdemo-check-$$"   # 'twdemo' prefix so `clean` reaps it if interrupted
  tmux kill-session -t "$S" 2>/dev/null || true
  tmux new-session -d -s "$S" 2>/dev/null

  # the status format strings, exactly as src/tmux.conf reads them
  EXPR_LEFT=' #{@repo} '
  EXPR_RIGHT=' #{@branch} '

  # case 1: inside a repo → shell pushes clean repo + branch (branch has NO subpath)
  tmux set -p -t "$S" @repo   'dev-env-setup'  >/dev/null 2>&1
  tmux set -p -t "$S" @branch 'vlad/fix-terms' >/dev/null 2>&1
  gl=$(tmux display-message -t "$S" -p "$EXPR_LEFT")
  gr=$(tmux display-message -t "$S" -p "$EXPR_RIGHT")
  [[ "$gl" == " dev-env-setup " ]]  && tok "status-left  shows repo"   || tbad "status-left shows repo"   "got '$gl'"
  [[ "$gr" == " vlad/fix-terms " ]] && tok "status-right shows branch" || tbad "status-right shows branch" "got '$gr'"

  # case 2: outside a repo → shell sets both empty; status clears (no stale value)
  tmux set -p -t "$S" @repo   '' >/dev/null 2>&1
  tmux set -p -t "$S" @branch '' >/dev/null 2>&1
  el=$(tmux display-message -t "$S" -p "$EXPR_LEFT")
  er=$(tmux display-message -t "$S" -p "$EXPR_RIGHT")
  [[ "$el" == "  " ]] && tok "status-left  clears when @repo empty"   || tbad "status-left clears"   "got '$el'"
  [[ "$er" == "  " ]] && tok "status-right clears when @branch empty" || tbad "status-right clears" "got '$er'"

  tmux kill-session -t "$S" 2>/dev/null || true
  echo "   └─ result: pass $tpass / fail $tfail"
  echo ""
  [[ "$tfail" -eq 0 ]] && { echo "🐢 shell yeah — footer splits clean 🌊"; exit 0; } || { echo "🐢 bummer dude — $tfail failed"; exit 1; }
fi

# ── demo mode: open a persistent role-tab window and LEAVE it open ────────────
# .why = show the real kitty tab bar with two role tabs (mechanic + foreman), each
#        attached to its own duct. unlike 'live', this does NOT clean up — the
#        window + sessions stay so a human can see the footer. reap with:
#          rhx termwork.test clean   (kills all twdemo-*/twtest-* sessions)
if [[ "$MODE" == "demo" ]]; then
  SDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  RROOT=$(git -C "$SDIR" rev-parse --show-toplevel 2>/dev/null || true)
  [[ -n "$RROOT" ]] || RROOT=$(cd "$SDIR/../../../.." && pwd)
  # shellcheck disable=SC1090
  source "$RROOT/src/termwork.sh"

  TREE="twdemo"
  echo "🐢 termwork demo — poppin a role window..."
  echo ""
  echo "🐚 termwork.test --demo"

  # findsert the two role ducts (idempotent: reuse if a prior demo left them)
  tmux has-session -t "$TREE/mechanic" 2>/dev/null || tmux new-session -d -s "$TREE/mechanic" -c "$RROOT"
  tmux has-session -t "$TREE/foreman"  2>/dev/null || tmux new-session -d -s "$TREE/foreman"  -c "$RROOT"
  echo "   ├─ ducts: $TREE/mechanic, $TREE/foreman"

  # preview the NEW status line WITHOUT touching the deployed config: set the repo/
  # branch format scoped to THESE sessions only (no -g, so the human's other sessions
  # keep their status). mirrors src/tmux.conf's status-left/right.
  for S in "$TREE/mechanic" "$TREE/foreman"; do
    tmux set -t "$S" status-left  " #{@repo} "   >/dev/null 2>&1
    tmux set -t "$S" status-right " #{@branch} " >/dev/null 2>&1
    tmux set -t "$S" status-left-length 40  >/dev/null 2>&1
    tmux set -t "$S" status-right-length 60 >/dev/null 2>&1
    # blank the middle window-status list (the "0:zsh*" segment) so only repo/branch show
    tmux set -t "$S" window-status-format ""         >/dev/null 2>&1
    tmux set -t "$S" window-status-current-format "" >/dev/null 2>&1
  done
  echo "   ├─ status line (session-scoped preview): left #{@repo}  right #{@branch}, no window-list"

  # if a demo window is already open, just focus it (idempotent)
  if [[ -n "$(__term_find_by_duct "$TREE")" ]]; then
    term.open --via kitty --on "$TREE" --for mechanic >/dev/null 2>&1
    echo "   └─ demo window already open — focused it"
    echo ""
    echo "🐢 righteous — look at the tab bar 🌊"
    exit 0
  fi

  # open the window: mechanic = base tab, foreman = added tab
  term.open --via kitty --on "$TREE" --for mechanic >/dev/null 2>&1
  sleep 0.6
  term.open --via kitty --on "$TREE" --for foreman  >/dev/null 2>&1
  sleep 0.6

  # source the repo zshrc in each pane so the REAL shell push fills @repo/@branch
  # (the deployed ~/.zshrc may lack the change; this previews it). the precmd hook
  # fires on the next prompt — which the banner send below triggers.
  for role in mechanic foreman; do
    term.send --via kitty --on "$TREE" --for "$role" --what "source '$RROOT/src/zshrc.sh'" >/dev/null 2>&1
  done
  sleep 0.5

  # drop a banner into each role so the human sees which tab is which
  term.send --via kitty --on "$TREE" --for mechanic --what "clear; echo '🔧 this is the MECHANIC tab  (duct: $TREE/mechanic)'" >/dev/null 2>&1
  term.send --via kitty --on "$TREE" --for foreman  --what "clear; echo '👷 this is the FOREMAN tab   (duct: $TREE/foreman)'"  >/dev/null 2>&1

  echo "   ├─ tab bar: [ mechanic ] [ foreman ]"
  echo "   ├─ footer:  left = repo (dev-env-setup)   right = branch"
  echo "   ├─ mechanic attaches $TREE/mechanic"
  echo "   ├─ foreman  attaches $TREE/foreman"
  echo "   └─ left OPEN — reap later with:  rhx termwork.test clean"
  echo ""
  echo "🐢 righteous — the window is up, check the tab bar + footer 🌊"
  exit 0
fi

# ── clean mode: reap any leftover twtest-* / twdemo-* sessions/windows ────────
# .why = the live test tags its sessions 'twtest-'; the demo tags 'twdemo'. if a
#        run is interrupted (or the demo is left open), sessions orphan. this reaps
#        ALL of either prefix, so it heals leftovers from any prior run or demo.
#        safe: only touches the twtest-/twdemo namespaces.
if [[ "$MODE" == "clean" ]]; then
  echo "🐢 termwork test (clean) — tidy the beach..."
  echo ""
  echo "🐚 termwork.test --clean"
  killed=0
  is_ours() { [[ "$1" == twtest-* || "$1" == twdemo* ]]; }
  if command -v tmux >/dev/null 2>&1; then
    while IFS= read -r s; do
      [[ -n "$s" ]] || continue
      if is_ours "$s"; then
        tmux kill-session -t "$s" 2>/dev/null && { echo "   ├─ killed tmux session: $s"; killed=$((killed+1)); }
      fi
    done < <(tmux list-sessions -F '#S' 2>/dev/null)
  fi
  # reap kitty windows still attached to one of our sessions (cmdline holds it)
  if command -v pgrep >/dev/null 2>&1; then
    while IFS= read -r pid; do
      [[ -n "$pid" ]] || continue
      if tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -Eq 'twtest-|twdemo'; then
        kill "$pid" 2>/dev/null && { echo "   ├─ killed kitty pid: $pid"; killed=$((killed+1)); }
      fi
    done < <(pgrep -x kitty 2>/dev/null)
  fi
  # drop stale termwork registry records for our terminals
  for f in "${TERMWORK_DIR:-$HOME/.termwork}"/*.json; do
    [[ -f "$f" ]] || continue
    if grep -Eq 'twtest-|twdemo' "$f" 2>/dev/null; then rm -f "$f"; echo "   ├─ dropped registry: $f"; fi
  done
  echo "   └─ reaped: $killed"
  echo ""
  [[ "$killed" -gt 0 ]] && echo "🐢 shell yeah — beach is clean 🌊" || echo "🐢 nothin to clean, all chill 🌴"
  exit 0
fi

# ── locate termwork.sh ───────────────────────────────────────────────────────
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)
[[ -n "$REPO_ROOT" ]] || REPO_ROOT=$(cd "$SCRIPT_DIR/../../../.." && pwd)
TERMWORK_SRC="$REPO_ROOT/src/termwork.sh"
if [[ ! -f "$TERMWORK_SRC" ]]; then
  echo "💥 termwork.test: cannot find termwork.sh at '$TERMWORK_SRC'" >&2
  exit 1
fi

PASS=0
FAIL=0

# ── assert ops ───────────────────────────────────────────────────────────────
_ok()   { PASS=$((PASS+1)); echo "   ✅ $1"; }
_bad()  { FAIL=$((FAIL+1)); echo "   ⛈️  $1"; [[ -n "${2:-}" ]] && echo "        $2"; }

assert_eq()       { [[ "$2" == "$3" ]] && _ok "$1" || _bad "$1" "want '$3' got '$2'"; }
assert_rc()       { [[ "$2" == "$3" ]] && _ok "$1" || _bad "$1" "want rc $3 got $2"; }
assert_has()      { grep -qF -- "$3" <<<"$2" && _ok "$1" || _bad "$1" "absent '$3'"; }
assert_hasnt()    { grep -qF -- "$3" <<<"$2" && _bad "$1" "found '$3'" || _ok "$1"; }
assert_loghas()   { grep -qF -- "$2" "$CALLLOG" && _ok "$1" || _bad "$1" "log lacks '$2'"; }
assert_lognot()   { grep -qF -- "$2" "$CALLLOG" && _bad "$1" "log has '$2'" || _ok "$1"; }

# ── syntax checks (both modes) ───────────────────────────────────────────────
run_syntax() {
  echo "   ├─ syntax"
  if bash -n "$TERMWORK_SRC" 2>/tmp/tw.syn; then _ok "bash -n"; else _bad "bash -n" "$(cat /tmp/tw.syn)"; fi
  if command -v zsh >/dev/null 2>&1; then
    if zsh -n "$TERMWORK_SRC" 2>/tmp/tw.syn; then _ok "zsh -n"; else _bad "zsh -n" "$(cat /tmp/tw.syn)"; fi
  else
    echo "   │  ⚠️  zsh absent — skipped zsh -n"
  fi
}

# ── stub mode ────────────────────────────────────────────────────────────────
run_stub() {
  TMP=$(mktemp -d)
  BIN="$TMP/bin"; mkdir -p "$BIN"
  export CALLLOG="$TMP/calls.log"; : > "$CALLLOG"
  export WINID="$TMP/winid"; echo 1 > "$WINID"    # base window id = 1; launches start at 2
  export FAKEPIDFILE="$TMP/fakepid"

  # fake `kitty` — the base-window spawn. logs its args, returns instantly.
  cat > "$BIN/kitty" <<'SH'
#!/usr/bin/env bash
echo "kitty $*" >> "$CALLLOG"
exit 0
SH
  # fake `kitten` — the IPC boundary (`kitten @ --to SOCKET SUBCMD ...`).
  cat > "$BIN/kitten" <<'SH'
#!/usr/bin/env bash
echo "kitten $*" >> "$CALLLOG"
sub="${4:-}"
case "$sub" in
  launch) id=$(cat "$WINID"); id=$((id+1)); echo "$id" > "$WINID"; echo "$id" ;;
  ls) echo '[{"tabs":[{"windows":[{"id":1}]}]}]' ;;
  get-text) echo "FAKE-TEXT" ;;
  send-text) cat >/dev/null 2>&1 || true ;;
  set-tab-title|focus-window|close-window) : ;;
  *) : ;;
esac
exit 0
SH
  # fake `tmux` — every has-session succeeds (pretend all ducts exist).
  cat > "$BIN/tmux" <<'SH'
#!/usr/bin/env bash
echo "tmux $*" >> "$CALLLOG"
exit 0
SH
  # fake `pgrep` — the spawned kitty's pid is whatever fakepid holds.
  cat > "$BIN/pgrep" <<'SH'
#!/usr/bin/env bash
cat "$FAKEPIDFILE"
SH
  chmod +x "$BIN"/*
  export PATH="$BIN:$PATH"

  export TERMWORK_DIR="$TMP/termwork"
  unset TERMWORK_BASE_TAB 2>/dev/null || true

  # shellcheck disable=SC1090
  source "$TERMWORK_SRC"
  if ! declare -f term.open >/dev/null || ! grep -q -- '--for' "$TERMWORK_SRC"; then
    echo "💥 termwork.test: term.open not loaded from $TERMWORK_SRC" >&2
    exit 1
  fi

  PIDS=()
  new_fake_kitty() {
    sleep 300 </dev/null >/dev/null 2>&1 &   # fds redirected so $() does not block
    local p=$!
    PIDS+=("$p")
    echo "$p" > "$FAKEPIDFILE"
    echo "$p"
  }
  cleanup() { for p in "${PIDS[@]:-}"; do kill "$p" 2>/dev/null || true; done; rm -rf "$TMP"; }
  trap cleanup EXIT

  echo "   ├─ validation"
  out=$(term.open --via kitty --for mechanic 2>&1); assert_rc "--for needs --on (rc)" "$?" 2
  assert_has "--for needs --on (msg)" "$out" "--for requires --on"
  out=$(term.open --via kitty --on w --for m --tab t 2>&1); assert_rc "--for + --tab rejected (rc)" "$?" 2
  assert_has "--for + --tab (msg)" "$out" "do not combine"
  out=$(term.open --via kitty --on user@host:w --for m 2>&1); assert_rc "remote --for rejected (rc)" "$?" 2
  assert_has "remote --for (msg)" "$out" "local-only"
  out=$(term.open --via kitty --duct srv 2>&1); assert_rc "--duct needs --tab (rc)" "$?" 2
  assert_has "--duct needs --tab (msg)" "$out" "requires --tab"

  echo "   ├─ scenario: roles on one terminal"
  KPID=$(new_fake_kitty)
  : > "$CALLLOG"
  term.open --via kitty --on worktree --for mechanic >/dev/null 2>&1
  assert_rc "open --for mechanic (rc)" "$?" 0
  REC="$TERMWORK_DIR/$KPID.json"
  assert_eq  "identity stays 'worktree'"        "$(jq -r '.duct'         "$REC" 2>/dev/null)" "worktree"
  assert_eq  "host local (empty)"               "$(jq -r '.host'         "$REC" 2>/dev/null)" ""
  assert_eq  "base tab titled 'mechanic'"       "$(jq -r '.tabs[0].slug'  "$REC" 2>/dev/null)" "mechanic"
  assert_loghas "base attaches worktree/mechanic" "attach-session -t 'worktree/mechanic'"

  : > "$CALLLOG"
  term.open --via kitty --on worktree --for foreman >/dev/null 2>&1
  assert_rc "open --for foreman (rc)" "$?" 0
  assert_eq  "2nd tab titled 'foreman'"         "$(jq -r '.tabs[1].slug'    "$REC" 2>/dev/null)" "foreman"
  assert_eq  "foreman kittyId captured"         "$(jq -r '.tabs[1].kittyId'  "$REC" 2>/dev/null)" "2"
  assert_loghas "foreman tab attaches worktree/foreman" "attach-session -t 'worktree/foreman'"
  assert_loghas "foreman tab titled 'foreman'"  "--tab-title foreman"
  assert_lognot "title is NOT the session name" "--tab-title worktree/foreman"

  : > "$CALLLOG"
  term.read --via kitty --on worktree --for foreman >/dev/null 2>&1
  assert_rc "read --for foreman (rc)" "$?" 0
  assert_loghas "read addresses tab by id"      "get-text --match id:2"
  assert_lognot "read never uses session name"  "worktree/foreman"

  : > "$CALLLOG"
  term.send --via kitty --on worktree --for foreman --what "echo hi" >/dev/null 2>&1
  assert_rc "send --for foreman (rc)" "$?" 0
  assert_loghas "send addresses tab by id"      "send-text --match id:2"

  : > "$CALLLOG"
  term.stop --via kitty --on worktree --for foreman >/dev/null 2>&1
  assert_rc "stop --for foreman (rc)" "$?" 0
  assert_eq  "foreman tab dropped from registry" "$(jq -r '.tabs | length' "$REC" 2>/dev/null)" "1"

  echo "   ├─ scenario: back-compat"
  KPID=$(new_fake_kitty)
  export TERMWORK_DIR="$TMP/termwork2"
  : > "$CALLLOG"
  term.open --via kitty --on plainduct --tab aux >/dev/null 2>&1
  assert_rc "open --tab aux (rc)" "$?" 0
  assert_loghas "base --tab aux attaches session 'aux'" "attach-session -t 'aux'"
  : > "$CALLLOG"
  term.open --via kitty --on plainduct --tab worker --duct realsession >/dev/null 2>&1
  assert_rc "open --tab worker --duct realsession (rc)" "$?" 0
  REC2="$TERMWORK_DIR/$KPID.json"
  assert_eq  "tab titled 'worker'"              "$(jq -r '.tabs[1].slug' "$REC2" 2>/dev/null)" "worker"
  assert_loghas "tab attaches overridden 'realsession'" "attach-session -t 'realsession'"
  assert_lognot "session name not used as title" "--tab-title realsession"
}

# ── live mode (real kitty + tmux) ────────────────────────────────────────────
run_live() {
  echo "   ├─ preflight"
  for b in tmux kitty kitten jq; do
    if command -v "$b" >/dev/null 2>&1; then _ok "$b present"; else _bad "$b present" "not installed"; return; fi
  done
  if [[ -z "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
    _bad "a display is available" "no WAYLAND_DISPLAY/DISPLAY — cannot spawn kitty"
    return
  fi

  # NOTE: these must be top-level (not `local`) — the EXIT trap fires AFTER
  # run_live returns, when any locals would already be out of scope, leaving the
  # cleanup with empty session names (a leak). top-level keeps them visible.
  LTMP=$(mktemp -d)
  export TERMWORK_DIR="$LTMP/termwork"
  unset TERMWORK_BASE_TAB 2>/dev/null || true
  # shellcheck disable=SC1090
  source "$TERMWORK_SRC"

  TREE="twtest-$$"
  S_MECH="$TREE/mechanic"
  S_FORE="$TREE/foreman"
  local MK="MECHMARK_$$"
  local FK="FOREMARK_$$"

  live_cleanup() {
    term.stop --via kitty --on "$TREE" >/dev/null 2>&1 || true
    # reap by prefix, not by remembered names — belt-and-suspenders against any
    # var that went out of scope, and catches sibling runs' leftovers too
    while IFS= read -r s; do
      [[ "$s" == twtest-* ]] && tmux kill-session -t "$s" 2>/dev/null || true
    done < <(tmux list-sessions -F '#S' 2>/dev/null)
    rm -rf "${LTMP:-/nonexistent}"
  }
  trap live_cleanup EXIT

  # 1. THE open question: does tmux accept '/' in a session name?
  echo "   ├─ tmux session names"
  if tmux new-session -d -s "$S_MECH" 2>/tmp/tw.tmux; then
    _ok "tmux accepts '/' in session name ($S_MECH)"
  else
    _bad "tmux accepts '/' in session name" "$(cat /tmp/tw.tmux) — the --for '/' convention is unusable as-is"
    return
  fi
  if tmux new-session -d -s "$S_FORE" 2>/tmp/tw.tmux; then _ok "created $S_FORE"; else _bad "created $S_FORE" "$(cat /tmp/tw.tmux)"; return; fi

  # 2. open terminal for mechanic role (base tab), then foreman (added tab)
  echo "   ├─ open role tabs"
  if term.open --via kitty --on "$TREE" --for mechanic >/tmp/tw.open 2>&1; then _ok "term.open --for mechanic"; else _bad "term.open --for mechanic" "$(cat /tmp/tw.open)"; return; fi
  sleep 0.6
  if term.open --via kitty --on "$TREE" --for foreman  >/tmp/tw.open 2>&1; then _ok "term.open --for foreman"; else _bad "term.open --for foreman" "$(cat /tmp/tw.open)"; return; fi
  sleep 0.6

  local pid socket
  pid=$(__term_find_by_duct "$TREE")
  [[ -n "$pid" ]] && _ok "terminal registered (pid $pid)" || { _bad "terminal registered" "no pid for $TREE"; return; }
  socket=$(__term_get_socket "$pid")

  # 3. REAL kitty shows two tabs, titled by role (not the session path)
  echo "   ├─ kitty tab bar"
  local titles
  titles=$(kitten @ --to "$socket" ls 2>/dev/null | jq -r '.[].tabs[].title' 2>/dev/null | paste -sd, -)
  assert_has "kitty shows a 'mechanic' tab" "$titles" "mechanic"
  assert_has "kitty shows a 'foreman' tab"  "$titles" "foreman"
  assert_hasnt "tab title is NOT the session path" "$titles" "$TREE/"

  # 4. REAL attach + decouple: send a marker to each role, read each back.
  #    each role must see ONLY its own marker → the tabs attach different ducts.
  echo "   ├─ real attach per role (ducts decoupled)"
  term.send --via kitty --on "$TREE" --for mechanic --what "echo $MK" >/dev/null 2>&1
  term.send --via kitty --on "$TREE" --for foreman  --what "echo $FK" >/dev/null 2>&1
  sleep 0.8
  local mech_txt fore_txt
  mech_txt=$(term.read --via kitty --on "$TREE" --for mechanic 2>/dev/null)
  fore_txt=$(term.read --via kitty --on "$TREE" --for foreman  2>/dev/null)
  assert_has  "mechanic tab shows its own marker"  "$mech_txt" "$MK"
  assert_hasnt "mechanic tab does NOT show foreman's marker" "$mech_txt" "$FK"
  assert_has  "foreman tab shows its own marker"   "$fore_txt" "$FK"
  assert_hasnt "foreman tab does NOT show mechanic's marker" "$fore_txt" "$MK"

  # 5. stop just the foreman tab; mechanic (base) survives
  echo "   ├─ stop one tab"
  term.stop --via kitty --on "$TREE" --for foreman >/dev/null 2>&1
  assert_rc "stop --for foreman (rc)" "$?" 0
  sleep 0.4
  local n
  n=$(kitten @ --to "$socket" ls 2>/dev/null | jq -r '[.[].tabs[]] | length' 2>/dev/null)
  assert_eq "one tab remains after foreman stop" "$n" "1"
}

# ── run ──────────────────────────────────────────────────────────────────────
echo "🐢 termwork test ($MODE) — heres the wave..."
echo ""
echo "🐚 termwork.test --$MODE"
echo "   ├─ src: $TERMWORK_SRC"
run_syntax
if [[ "$MODE" == "live" ]]; then run_live; else run_stub; fi

echo "   └─ result"
echo "      ├─ pass: $PASS"
echo "      └─ fail: $FAIL"
echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "🐢 shell yeah — all $PASS checks green 🌊"
  exit 0
fi
echo "🐢 bummer dude — $FAIL check(s) failed"
exit 1
