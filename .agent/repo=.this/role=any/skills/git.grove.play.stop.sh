#!/usr/bin/env bash
######################################################################
# .what = stop a play that runs on a grove: the play, and every process
#         under it, then remove the scratch dirs the play names
#
# .why  a duct IS tmux, so a play holds its pane, and a send down that pane
#       lands in the play's stdin rather than stop it. a bound from outside —
#       a disk gate, a crew that must stay live — needs the play gone NOW,
#       and the stop must reach the children too: a play's work runs in its
#       children (a restore's gzip), and a TERM to the play alone orphans them
#
# usage:
#   rhx git.grove.play.stop <grove> --play <name>
#   rhx git.grove.play.stop <grove> --play <name> --scratch '.local/state/<prefix>.*'
#
# guarantee:
#   - asks over its own ssh, around the pane (as git.grove.play.await does)
#   - scoped to the ssh user's own processes; the pattern names the play FILE
#   - TERM to the play and each descendant, KILL to any left after 5s
#   - --scratch globs are relative to $HOME and must sit under .local/state/
#   - reports the processes stopped, the scratch removed, and the disk after
#   - a pgrep that cannot answer is no "none ran": it exits 1, as await reads it
#   - exit 0 = stopped (or none ran) · 1 = the box or its pgrep did not answer · 2 = bad args
######################################################################
set -uo pipefail

GROVE=""
PLAY=""
SCRATCH=""
while [[ $# -gt 0 ]]; do
  # a value flag with no value refuses: `shift 2` past the last arg shifts naught,
  # so the loop would read the same flag forever
  [[ "$1" =~ ^--(play|scratch|repo|role|skill)$ && $# -lt 2 ]] && {
    echo "✋ ConstraintError: $1 needs a value" >&2
    echo "   fix: rhx git.grove.play.stop <grove> --play <name>" >&2; exit 2; }
  case "$1" in
    --play)    PLAY="${2:-}"; shift 2 ;;
    --scratch) SCRATCH="${2:-}"; shift 2 ;;
    --help|-h) sed -n '/^# usage:/,/^######/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//;$d'; exit 0 ;;
    --repo|--role|--skill) shift 2 ;;
    -*) echo "✋ ConstraintError: unknown arg '$1'" >&2; echo "   fix: rhx git.grove.play.stop <grove> --play <name>" >&2; exit 2 ;;
    *)  [[ -z "$GROVE" ]] || { echo "✋ ConstraintError: two groves named: '$GROVE' and '$1'" >&2; exit 2; }
        GROVE="$1"; shift ;;
  esac
done
[[ -n "$GROVE" && -n "$PLAY" ]] || { echo "✋ ConstraintError: a grove and --play are required" >&2
  echo "   fix: rhx git.grove.play.stop <grove> --play <name>" >&2; exit 2; }
[[ "$PLAY" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "✋ ConstraintError: --play takes a play name, got '$PLAY'" >&2; exit 2; }
if [[ -n "$SCRATCH" ]]; then
  [[ "$SCRATCH" == .local/state/* && "$SCRATCH" != *..* && "$SCRATCH" =~ ^[A-Za-z0-9._/*-]+$ ]] \
    || { echo "✋ ConstraintError: --scratch must name a glob under .local/state/, got '$SCRATCH'" >&2; exit 2; }
fi

# the lib brings the checkout's ductwork along: the duct grammar and the escape sink
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/git.grove.operations.sh"
__duct_parse_uri "duct://$GROVE/main/mechanic" || { echo "💥 MalfunctionError: could not parse the duct for $GROVE" >&2; exit 1; }

# the far procedure: base64'd, since ssh hands its argv to a login shell as code
pattern="$(_play_pattern "$PLAY")"
remote="$(cat <<EOF
pat='$pattern'
kids() { local p; for p in "\$@"; do echo "\$p"; kids \$(pgrep -P "\$p"); done; }
roots=\$(pgrep -u "\$(id -u)" -f -- "\$pat"); prc=\$?
# three answers, never two: pgrep 0 = a match, 1 = none; any other code is no answer
case "\$prc" in 0|1) ;; *) echo "pgrep could not answer (rc \$prc)"; exit 3 ;; esac
all=\$(kids \$roots | sort -u | tr '\n' ' ')
echo "stopped: \${all:-none}"
[ -n "\$all" ] && kill -TERM \$all 2>/dev/null
left=""
for i in 1 2 3 4 5; do left=""; for p in \$all; do kill -0 "\$p" 2>/dev/null && left="\$left \$p"; done; [ -z "\$left" ] && break; sleep 1; done
[ -n "\$left" ] && kill -KILL \$left 2>/dev/null && echo "killed after 5s:\$left"
scratch='$SCRATCH'
if [ -n "\$scratch" ]; then for d in "\$HOME"/\$scratch; do [ -e "\$d" ] && rm -rf -- "\$d" && echo "removed: \${d#\$HOME/}"; done; fi
df -h --output=pcent,avail "\$HOME" | tail -n 1 | sed 's/^/disk after: /'
EOF
)"
b64="$(printf '%s' "$remote" | base64 | tr -d '\n')"

echo "🛑 git.grove.play.stop $GROVE --play $PLAY${SCRATCH:+ --scratch '$SCRATCH'}"
out="$(timeout -k 5 60 ssh -o BatchMode=yes -o ConnectTimeout=10 "$DUCT_HOST" "bash -c \"\$(printf %s '$b64' | base64 -d)\"" </dev/null 2>&1)"; rc=$?
if [[ "$rc" -eq 3 ]]; then
  echo "💥 MalfunctionError: the grove answered, but its pgrep did not, so no play was seen or stopped" >&2
  printf '%s\n' "$out" | __duct_strip_escapes | sed 's/^/   └─ /' >&2; exit 1
fi
[[ "$rc" -eq 0 ]] || { echo "💥 MalfunctionError: the grove was not asked (ssh rc $rc)" >&2
  echo "   fix: rhx git.grove.wake $GROVE --mode apply, then rerun" >&2; exit 1; }
printf '%s\n' "$out" | __duct_strip_escapes | sed 's/^/   ├─ /'
echo "   └─ done"
