#!/usr/bin/env bash
######################################################################
# .what = measure process churn — the fork rate, and who drives it
#
# .why  = a load that no long-lived process explains is a CHURN load:
#         hundreds of short-lived spawns per second, each alive for
#         under a second. every per-process tool is blind to it, since
#         by the time it reads /proc/<pid>, that pid is gone.
#
#         the only durable evidence is a RATE, so this samples one:
#           - forks/sec from /proc/stat's monotonic `processes` counter
#           - a repeated ps sweep, to catch the names that keep
#             reappearing across samples
#
#         `ps` + `top` answer "who is heavy NOW". this answers "who
#         keeps being born", which is a different question and the only
#         one a churn load responds to.
#
# usage:
#   machine.diagnose.churn.sh                # 5s sample
#   machine.diagnose.churn.sh --secs 15      # longer, steadier sample
#   machine.diagnose.churn.sh --sweeps 40    # denser name sweep
#
# options:
#   --secs N     seconds to sample over (default 5)
#   --sweeps N   how many ps sweeps across the window (default 20)
#   --help, -h   show usage and exit
#
# guarantee:
#   - read-only; spawns nothing but its own ps sweeps
#   - exits 0 always (a report is not a verdict)
######################################################################
# .note = `pipefail` is deliberately absent; the sweep pipelines end in
#         a bounded cut, and an early exit there is intent, not fault.
set -eu

SECS=5
SWEEPS=20

while [[ $# -gt 0 ]]; do
  case "$1" in
    --secs)   SECS="$2"; shift 2 ;;
    --sweeps) SWEEPS="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    # absorb harness-injected args; `rhx <skill>` prepends --repo/--role/--skill
    --repo|--role|--skill) shift 2 ;;
    *) echo "✋ unknown arg: $1" >&2; exit 2 ;;
  esac
done

CORES=$(nproc)
read -r L1 _ _ _ < /proc/loadavg

######################################################################
# the fork rate — the one number a churn load cannot hide
#
# /proc/stat's `processes` field counts every fork since boot and never
# resets, so a delta over a known window is an exact rate. no sampling
# error, no missed short-lived pid.
######################################################################

FORKS_A=$(awk '/^processes/{print $2}' /proc/stat)
CTX_A=$(awk '/^ctxt/{print $2}' /proc/stat)

# sweep names while the window runs. a name that appears in many sweeps
# is either long-lived OR reborn constantly — the pid tells them apart,
# so track distinct pids per name, not sweep hits.
SWEEP_TMP=$(mktemp)
trap 'rm -f "$SWEEP_TMP"' EXIT

# .note = python-free, awk-free interval math: bash has no float, so the
#         gap is derived in awk once and reused as a plain sleep arg.
GAP=$(awk -v s="$SECS" -v n="$SWEEPS" 'BEGIN{printf "%.3f", s/n}')

for _ in $(seq 1 "$SWEEPS"); do
  ps -eo pid=,ppid=,comm= >> "$SWEEP_TMP" 2>/dev/null || true
  sleep "$GAP"
done

FORKS_B=$(awk '/^processes/{print $2}' /proc/stat)
CTX_B=$(awk '/^ctxt/{print $2}' /proc/stat)

FORK_TOTAL=$((FORKS_B - FORKS_A))
FORK_RATE=$(awk -v f="$FORK_TOTAL" -v s="$SECS" 'BEGIN{printf "%.0f", f/s}')
CTX_RATE=$(awk -v c="$((CTX_B - CTX_A))" -v s="$SECS" 'BEGIN{printf "%.0f", c/s}')

######################################################################
# who churns — distinct pids per name across the window
#
# a steady daemon shows 1 distinct pid no matter how many sweeps see it.
# a churner shows dozens, because each sweep catches a different birth.
# that ratio is the whole diagnosis.
######################################################################

CHURN=$(sort -u "$SWEEP_TMP" \
  | awk '{ n[$3]++ } END { for (k in n) printf "%d\t%s\n", n[k], k }' \
  | sort -rn | awk 'NR<=8')

# .what = which LIVE process fathered the churn
#
# .why  = the churner's own name is generic — "sh", "node", "bash" name a
#         runtime, never a culprit. the parent is the accountable party,
#         and it is long-lived, so unlike its children it can be read.
#         this is the step that turns "384 forks/sec" into a name to act on.
#
# .note = shells and runtimes only; a parent that spawns `ps` or `sleep`
#         does ordinary work, and a tally of those buries the signal.
#
# .note = ppid 1 is excluded, and the exclusion is the point. every orphan on
#         the box reparents to init, so init aggregates the leftovers of every
#         dead chain and outranks the real culprits by sheer accumulation. it
#         once topped this list and the report advised "cut pid=1", which no
#         human can act on. the orphan count is reported on its own line
#         instead — a real signal (chains die mid-flight) that names a
#         different fix than a heavy parent does.
PARENTS=$(sort -u "$SWEEP_TMP" \
  | awk '$2 != 1 && $3 ~ /^(sh|bash|zsh|node|run\.bun|npm|npx)/ { n[$2]++ }
         END { for (k in n) printf "%d\t%s\n", n[k], k }' \
  | sort -rn | awk 'NR<=6' \
  | while IFS=$'\t' read -r count ppid; do
      # look up each pid's name; a dead parent means the chain
      # already reparented, which is itself worth the report
      who=$(ps -o args= -p "$ppid" 2>/dev/null | cut -c1-58)
      [[ -z "$who" ]] && who="[exited — its children reparented]"
      # a host is read from its OWN comm, never its cmdline. a tmux server
      # keeps the `tmux new-session ...` cmdline of whichever client
      # daemonized it, so the cmdline reads like a spawn while the comm reads
      # `tmux`. classify on comm; carry the cmdline only as a label.
      comm=$(ps -o comm= -p "$ppid" 2>/dev/null)
      kind="spawner"
      case "$comm" in
        tmux*|screen|kitty|alacritty|ptyxis|gnome-terminal*|konsole|xterm|foot|wezterm*|\
        sshd|systemd|cosmic-comp|gnome-shell|Xorg|Xwayland|dbus-daemon)
          kind="host" ;;
      esac
      printf '%d\t%s\t%s\t%s\n' "$count" "$ppid" "$who" "$kind"
    done)

# .what = split the blame list into what a human may cut, and what they may not
#
# .why  = a HOST aggregates the spawns of every workload beneath it, the same
#         way init aggregates orphans. its count is high because it is a
#         container, not because it is a culprit — so a cut on it destroys the
#         work rather than the storm.
#
#         measured 2026-09-05: this report ranked `pid=38244 tmux new-session
#         -d -s rhachet-brains-...` first at 57 spawns and advised "the
#         heaviest parent is where to cut". that pid was the tmux SERVER —
#         `tmux new-session -d` daemonizes into the server when none is live,
#         and the server keeps that cmdline for its whole life. the cut killed
#         six live work sessions and not one fork of the storm.
#
#         this is the pid=1 defect one layer up: parenthood proxied for agency
#         (rule.require.name-what-you-measured). the fix is the same shape —
#         hold the host out of the actionable list, and report it on its own
#         line with what it actually means.
SPAWNERS=$(printf '%s\n' "$PARENTS" | awk -F'\t' '$4 == "spawner"')
HOSTS=$(printf '%s\n' "$PARENTS" | awk -F'\t' '$4 == "host"')

# .what = churners whose parent already died, so init adopted them
#
# .why  = these are excluded from the blame list above (init is not an
#         accountable party), but their count is a distinct finding: a
#         chain that dies mid-flight leaves work half-done, and a high
#         orphan count names a different fix than a heavy parent does.
ORPHANS=$(sort -u "$SWEEP_TMP" \
  | awk '$2 == 1 && $3 ~ /^(sh|bash|zsh|node|run\.bun|npm|npx)/ { n++ }
         END { print n+0 }')

######################################################################
# report
######################################################################

echo ""
echo "🐈 heres the churn...  (${SECS}s sample, ${SWEEPS} sweeps)"
echo "   │"
echo "   ├─ 🌕 forks:  ${FORK_RATE}/sec  (${FORK_TOTAL} over ${SECS}s)"
echo "   ├─ 🌕 ctxsw:  ${CTX_RATE}/sec   (context switches)"
echo "   ├─ 🌕 load:   ${L1} on ${CORES} cores"
echo "   ├─ 🌕 born:   distinct pids seen per name, this window"
printf '%s\n' "$CHURN" | awk -F'\t' \
  '{printf "   │     ├─ %-18s %3d distinct pids\n", $2, $1}'
echo "   │"
echo "   └─ 🌕 blame:  the live parent each churner was forked from"
if [[ -z "$SPAWNERS" && -z "$HOSTS" ]]; then
  echo "         └─ 🌴 no shell/runtime churn to attribute"
fi
if [[ -n "$SPAWNERS" ]]; then
  printf '%s\n' "$SPAWNERS" | awk -F'\t' -v n="$(printf '%s\n' "$SPAWNERS" | grep -c .)" \
    '{printf "         %s %3d spawns  pid=%-8s %s\n", (NR==n ? "└─" : "├─"), $1, $2, $3}'
fi
# hosts print BELOW the actionable list and are marked, so the eye never reads
# a container as a culprit. they are never a `kill` target.
if [[ -n "$HOSTS" ]]; then
  printf '%s\n' "$HOSTS" | awk -F'\t' \
    '{printf "         ·  %3d spawns  pid=%-8s %s\n", $1, $2, $3}
     {printf "                        ↳ host — it CONTAINS the work; a kill here ends the work, not the storm\n"}'
fi
if [[ "$ORPHANS" -gt 0 ]]; then
  echo "         ·  ${ORPHANS} orphans  pid=1        [parent died — init adopted them]"
fi

echo ""
echo "🐈 heres what concerns me..."
echo "   │"

# a healthy interactive desktop idles near 5-20 forks/sec. 50+ is a
# storm: at ~5ms of kernel work per fork+exec, 50/sec is a core spent on
# process setup alone, before any of that work does anything useful.
if [[ "$FORK_RATE" -ge 50 ]]; then
  # .note = an empty TOP_BLAME must never print as a blank fix. the storm is
  #         real either way, so the concern still fires — but with a fix that
  #         names the next probe rather than an absent name.
  # .note = the fix names a PROBE, never a kill. this report cannot tell a
  #         busy workload from a runaway one — both fork fast — so a kill it
  #         recommends is a kill it cannot justify. it once said "the heaviest
  #         parent is where to cut" and cost a human six live work sessions.
  #         the skill's job ends at the name; the human decides the cut.
  TOP_BLAME=$(printf '%s\n' "$SPAWNERS" | awk -F'\t' 'NR==1{printf "pid=%s %s", $2, $3}')
  echo "   ├─ 🔥 ${FORK_RATE} forks/sec — a spawn storm, not a workload"
  if [[ -n "$TOP_BLAME" ]]; then
    echo "   │  └─ 🪄 the heaviest spawner — read what it forks BEFORE you cut:"
    echo "   │     ├─ ${TOP_BLAME}"
    echo "   │     └─ 🪄 see its children:  ps --ppid $(printf '%s\n' "$SPAWNERS" | awk -F'\t' 'NR==1{print $2}') -o pid=,etimes=,args="
  elif [[ -n "$HOSTS" ]]; then
    echo "   │  └─ 🪄 every heavy parent is a HOST (a terminal/session container)"
    echo "   │     ├─ the storm runs INSIDE one; the host is not the culprit"
    echo "   │     └─ 🪄 widen the window to reach the real spawner:  rhx machine.diagnose.churn --secs 15"
  else
    echo "   │  └─ 🪄 no live parent held the churn — every chain reparented"
    echo "   │     └─ 🪄 widen the window:  rhx machine.diagnose.churn --secs 15"
  fi
  echo "   │"
  echo "   └─ 🌊 a churn load is invisible to ps and top"
  echo "      └─ 🪄 each spawn dies before it can be read; only this rate sees it"
  echo ""
  exit 0
fi

echo "   └─ 🌴 fork rate is calm — this load is not churn; look for a hog instead"
echo "      └─ 🪄 rhx machine.usage.diagnose"
echo ""
