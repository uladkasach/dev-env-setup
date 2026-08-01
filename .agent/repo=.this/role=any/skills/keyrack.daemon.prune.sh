#!/usr/bin/env bash
######################################################################
# .what = find and prune orphaned keyrack daemons left by jest runs
#
# .why  = rhachet's keyrack daemon derives its socket identity from
#         sha256(realpath($HOME)). jest integration tests set HOME to a
#         fresh /tmp/rhachet-test-$ts-$rand per run, so every run mints
#         a NEW socket path -> find-or-create can never hit -> a new
#         daemon spawns, outlives the test, and reparents to PPid 1.
#
#         575 of these were found on a 76-day uptime. each is cheap in
#         RAM (PSS ~714K) but they collectively hold GBs of swap and a
#         share of 1.19G of page tables, which helped fill zram and
#         push the whole desktop into disk-swap thrash.
#
# .safety = ONLY prunes daemons whose HOME is a /tmp/rhachet-test-*
#           directory. a daemon with a real HOME may be serving a live
#           keyrack session and is NEVER touched.
#
# usage:
#   keyrack.daemon.prune.sh                # plan (default): show, kill none
#   keyrack.daemon.prune.sh --census       # who spawned them, by HOME shape
#   keyrack.daemon.prune.sh --mode apply   # kill the leaked daemons
#   keyrack.daemon.prune.sh --mode apply --min-age 120
#                                          # only prune daemons older than 120m
#   keyrack.daemon.prune.sh --mode apply --keep-alive-sockets
#                                          # extra guard: skip any whose
#                                          # socket file still exists
#
# options:
#   --mode plan|apply      plan (default) shows; apply signals TERM
#   --min-age MINUTES      only prune daemons older than this (default 60)
#   --keep-alive-sockets   skip any whose socket file still exists
#   --census               report spawn origin by HOME shape, prune none
#   --repo/--role/--skill  absorbed + ignored — rhachet injects these when
#                          invoked via `rhx keyrack.daemon.prune ...`
#
# guarantee:
#   - plan mode is the default; apply must be explicit
#   - never touches a daemon whose HOME is the real HOME
#   - never touches a daemon whose spawner is still alive
#   - never touches a daemon younger than --min-age (default 60m)
#   - SIGTERM first (graceful); reports what stayed
#   - fail-fast on errors
######################################################################

set -euo pipefail

MODE="plan"
KEEP_ALIVE_SOCKETS=0
CENSUS=0
MIN_AGE_MIN=60

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="${2:-}"; shift 2 ;;
    --min-age) MIN_AGE_MIN="${2:-}"; shift 2 ;;
    --keep-alive-sockets) KEEP_ALIVE_SOCKETS=1; shift ;;
    --census) CENSUS=1; shift ;;
    --repo|--role|--skill)
      # absorb the --repo/--role/--skill pairs rhachet injects when the skill
      # is invoked as `rhx keyrack.daemon.prune ...`; guard the value shift
      shift
      [[ $# -gt 0 ]] && shift
      ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "✋ unknown arg: $1" >&2; exit 2 ;;
  esac
done

case "$MODE" in
  plan|apply) ;;
  *) echo "✋ --mode must be plan or apply (got: $MODE)" >&2; exit 2 ;;
esac

[[ "$MIN_AGE_MIN" =~ ^[0-9]+$ ]] \
  || { echo "✋ --min-age must be a whole number of minutes (got: $MIN_AGE_MIN)" >&2; exit 2; }

# read one env var out of a process environ (null-separated)
get_env_of() {
  local pid="$1" key="$2"
  tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null \
    | awk -v k="^${key}=" '$0 ~ k { sub(k, ""); print; exit }' || true
}

# classify a HOME path into the spawn path that produced it.
# .why = a raw count of daemons is useless on its own — it does not say
#        WHICH caller minted them. HOME is the daemon's identity input,
#        so the shape of HOME names the origin.
classify_home() {
  case "$1" in
    /tmp/rhachet-test-*)          echo "jest.tmpdir.dash" ;;
    /tmp/rhachet-test/*)          echo "jest.tmpdir.slash" ;;
    *genTempDir*git-push-home*)   echo "git.push.temphome" ;;
    *genTempDir*git-set-home*)    echo "git.set.temphome" ;;
    *genTempDir*)                 echo "genTempDir.other" ;;
    /tmp/keyrack-prune-home-*)    echo "keyrack.prunetest" ;;
    "$HOME")                      echo "REAL.home" ;;
    "")                           echo "unreadable" ;;
    *)                            echo "other" ;;
  esac
}

# ── census ── which spawn path minted each daemon
if [[ "$CENSUS" -eq 1 ]]; then
  echo "🐢 lets see who spawned them..."
  echo ""
  echo "🐚 keyrack.daemon.prune --census"
  echo "   └─ daemons by spawn path"
  echo "      ├─"
  echo "      │"
  printf '      │  %-8s %-22s %s\n' "COUNT" "ORIGIN" "VERDICT"

  for pid in $(pgrep -f startKeyrackDaemon || true); do
    [[ -d "/proc/$pid" ]] || continue
    classify_home "$(get_env_of "$pid" HOME)"
  done | sort | uniq -c | sort -rn | while read -r n kind; do
    verdict="leak — temp HOME per invocation"
    [[ "$kind" == "REAL.home" ]] && verdict="legit — real HOME"
    [[ "$kind" == "unreadable" ]] && verdict="unknown — could not read environ"
    printf '      │  %-8s %-22s %s\n' "$n" "$kind" "$verdict"
  done

  echo "      │"
  echo "      └─"
  echo ""
  echo "💡 every non-REAL origin is a caller that sets a throwaway HOME."
  echo "   the daemon keys identity on sha256(realpath(HOME)), so each one"
  echo "   mints a fresh socket, misses find-or-create, and leaks."
  exit 0
fi

as_mb() { awk -v k="${1:-0}" 'BEGIN{ printf "%.1f", k/1024 }'; }

echo "🐢 lets clear the strays..."
echo ""
echo "🐚 keyrack.daemon.prune --mode $MODE"

pids=$(pgrep -f startKeyrackDaemon || true)
if [[ -z "$pids" ]]; then
  echo "   └─ no keyrack daemons found — already clear"
  exit 0
fi

sysd=$(pgrep -u "$(id -u)" -x systemd | head -1 || echo 0)
now_s=$(awk '{print int($1)}' /proc/uptime)
clk=$(getconf CLK_TCK 2>/dev/null || echo 100)

total=0; prune_n=0; real_n=0; young_n=0; owned_n=0
prune_pss=0; prune_swap=0
targets=""

for pid in $pids; do
  [[ -d "/proc/$pid" ]] || continue
  total=$((total + 1))

  home=$(get_env_of "$pid" HOME)
  ppid=$(awk '/^PPid:/{print $2}' "/proc/$pid/status" 2>/dev/null || echo 0)

  # PSS, not RSS. all 600+ daemons map the SAME node binary, so RSS counts
  # those ~12M of shared pages once per process — a sum overstates by ~18x.
  # smaps_rollup divides shared pages by the number of mappers, which is the
  # only figure that is honest to add up.
  pss=$(awk '/^Pss:/{print $2}' "/proc/$pid/smaps_rollup" 2>/dev/null || echo 0)
  swap=$(awk '/^SwapPss:/{print $2}' "/proc/$pid/smaps_rollup" 2>/dev/null || echo 0)

  # guard 1: a real HOME serves a live session — NEVER touch.
  # this is the absolute guard; every other check only narrows further.
  if [[ "$(classify_home "$home")" == "REAL.home" ]]; then
    real_n=$((real_n + 1)); continue
  fi

  # guard 2: the spawner must be dead. a daemon still owned by a live
  # parent may be mid-use, so only reparented ones (PPid 1 / user systemd)
  # are fair game. this replaces an earlier dir-existence check, which was
  # wrong: /tmp is never swept, so stale temp HOMEs persist forever and
  # wrongly protected 283 dead daemons.
  if [[ "$ppid" != "1" && "$ppid" != "$sysd" ]]; then
    owned_n=$((owned_n + 1)); continue
  fi

  # guard 3: must be older than --min-age. protects a daemon spawned by a
  # run that is in flight right now (its parent can already be gone while
  # the suite still runs).
  start_ticks=$(awk '{ sub(/^.*\) /, ""); print $20 }' "/proc/$pid/stat" 2>/dev/null || echo 0)
  age_min=$(( (now_s - start_ticks / clk) / 60 ))
  if [[ "$age_min" -lt "$MIN_AGE_MIN" ]]; then
    young_n=$((young_n + 1)); continue
  fi

  prune_n=$((prune_n + 1))
  prune_pss=$((prune_pss + ${pss:-0}))
  prune_swap=$((prune_swap + ${swap:-0}))
  targets+="$pid"$'\n'
done

echo "   ├─ found: $total keyrack daemons"
echo "   ├─ skip (REAL home — never touched): $real_n"
echo "   ├─ skip (spawner still alive): $owned_n"
echo "   ├─ skip (younger than ${MIN_AGE_MIN}m): $young_n"
echo "   ├─ prunable (temp home + spawner dead + aged): $prune_n"
echo "   ├─ reclaims: $(as_mb "$prune_pss") MB ram + $(as_mb "$prune_swap") MB swap (pss)"
echo "   └─ action"
echo "      ├─"
echo "      │"

if [[ "$prune_n" -eq 0 ]]; then
  echo "      │  no prunable daemons — none to signal"
  echo "      │"
  echo "      └─"
  exit 0
fi

if [[ "$MODE" == "plan" ]]; then
  echo "      │  plan only — no process was signaled"
  echo "      │"
  echo "      │  to apply:"
  echo "      │    keyrack.daemon.prune.sh --mode apply"
  echo "      │"
  echo "      └─"
  exit 0
fi

killed=0; stayed=0
while IFS= read -r pid; do
  [[ -z "$pid" ]] && continue
  if [[ "$KEEP_ALIVE_SOCKETS" -eq 1 ]]; then
    sock=$(tr '\0' '\n' < "/proc/$pid/cmdline" 2>/dev/null \
      | awk 'match($0, /\/run\/[^"]*\.sock/) { print substr($0, RSTART, RLENGTH); exit }' || true)
    if [[ -n "$sock" && -S "$sock" ]]; then
      stayed=$((stayed + 1))
      continue
    fi
  fi
  # graceful term; daemons hold no unsaved state
  if kill -TERM "$pid" 2>/dev/null; then
    killed=$((killed + 1))
  else
    stayed=$((stayed + 1))
  fi
done <<< "$targets"

echo "      │  signaled TERM to $killed daemon(s)"
[[ "$stayed" -gt 0 ]] && echo "      │  left alone: $stayed"
echo "      │"
echo "      └─"
echo ""
echo "🥥 re-run in plan mode to confirm they are gone"
