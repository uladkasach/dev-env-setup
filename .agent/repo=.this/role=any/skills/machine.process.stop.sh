#!/usr/bin/env bash
######################################################################
# .what = stop every process whose full argv holds a fixed string
#
# .why  = a spawn loop is named by `machine.diagnose.loop` with one argv.
#         to end it by hand costs a pgrep, a review, and a kill per name;
#         this pairs the review and the kill, with a plan before any signal
#
# usage:
#   rhx machine.process.stop --match 'director.shiptree.sh'              # plan
#   rhx machine.process.stop --match 'director.shiptree.sh' --mode apply # SIGTERM
#   rhx machine.process.stop --match 'duct.poll.sh' --mode apply --signal KILL
#   rhx machine.process.stop --match 'feat-x' --long    # full argv, parent, age, cwd
#
# guarantee:
#   - --match is a FIXED string, never a regex; matched against the full argv
#   - plan is the default: it lists each match and sends no signal
#   - --long reads parent pid, age, cwd, and the whole argv, so a leak is read
#     before it is cut (a cwd marked "(deleted)" = its test dir is gone)
#   - never signals its own process tree, nor a protected comm
#     (kitty, tmux, claude, systemd, init, sshd, Xwayland, cosmic-*)
#   - exit 0 = done · 1 = a signal failed · 2 = bad input
######################################################################
set -uo pipefail

match="" mode="plan" signal="TERM" long=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --match)  match="${2:-}"; shift 2 ;;
    --long)   long=1; shift ;;
    --mode)   mode="${2:-}"; shift 2 ;;
    --signal) signal="${2:-}"; shift 2 ;;
    # absorb harness-injected args; `rhx <skill>` prepends --repo/--role/--skill
    --repo|--role|--skill) shift 2 ;;
    -h|--help) sed -n '2,21p' "$0"; exit 0 ;;
    *) echo "✋ ConstraintError: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

# reject absent or malformed input
[[ ${#match} -ge 6 ]] || { echo "✋ ConstraintError: --match needs at least 6 characters, so it names one loop" >&2; exit 2; }
[[ "$mode" == plan || "$mode" == apply ]] || { echo "✋ ConstraintError: --mode is plan or apply" >&2; exit 2; }
[[ "$signal" == TERM || "$signal" == KILL || "$signal" == INT ]] || { echo "✋ ConstraintError: --signal is TERM, INT, or KILL" >&2; exit 2; }

# .what = this process and every ancestor, so the skill never signals its caller
__stop_self_tree() {
  local cur=$$
  while [[ -n "$cur" && "$cur" != 0 ]]; do
    echo "$cur"
    cur="$(awk '/^PPid:/ { print $2 }' "/proc/$cur/status" 2>/dev/null)"
  done
}
self="$(__stop_self_tree | tr '\n' ' ')"

# .what = pid, comm, argv of each match — protected comms and the self tree excluded
hits="$(ps -eo pid=,comm=,args= | awk -v m="$match" -v self=" $self " '
  {
    pid = $1; comm = $2
    argv = $0; sub(/^ *[0-9]+ +[^ ]+ +/, "", argv)
    if (index(argv, m) == 0) next
    if (index(self, " " pid " ")) next
    if (index(argv, "machine.process.stop")) next   # its own $(…) subshells carry its argv
    if (comm ~ /^(kitty|tmux|tmux: server|claude|systemd|init|sshd|Xwayland|cosmic-.*|ps|awk)$/) next
    printf "%s\t%s\t%s\n", pid, comm, substr(argv, 1, 140)
  }')"

echo "🐈 heres who holds '$match'..."
echo "   │"
if [[ -z "$hits" ]]; then
  echo "   └─ 🌴 no live process holds it"
  exit 0
fi

count="$(printf '%s\n' "$hits" | wc -l)"
printf '%s\n' "$hits" | head -n 12 | while IFS=$'\t' read -r pid comm argv; do
  printf '   ├─ %-8s %-10s %s\n' "$pid" "$comm" "$argv"
  [[ $long -eq 1 ]] || continue
  # read the rest of the record straight from /proc; a gone pid prints naught
  ppid="$(awk '/^PPid:/ { print $2 }' "/proc/$pid/status" 2>/dev/null)"
  age="$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')"
  cwd="$(readlink "/proc/$pid/cwd" 2>/dev/null)"
  full="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | cut -c1-600)"
  pargv="$(tr '\0' ' ' < "/proc/$ppid/cmdline" 2>/dev/null | cut -c1-200)"
  echo "   │  ├─ age:    ${age:-?}s"
  echo "   │  ├─ cwd:    ${cwd:-?}"
  echo "   │  ├─ parent: ${ppid:-?} ${pargv}"
  echo "   │  └─ argv:   ${full}"
done
[[ $count -gt 12 ]] && echo "   ├─ … and $((count - 12)) more"

if [[ "$mode" == plan ]]; then
  echo "   └─ $count would get SIG$signal — rerun with --mode apply"
  exit 0
fi

failed=0
for pid in $(printf '%s\n' "$hits" | awk -F'\t' '{ print $1 }'); do
  kill "-$signal" "$pid" 2>/dev/null || { [[ -d "/proc/$pid" ]] && failed=$((failed + 1)); }
done
if [[ $failed -gt 0 ]]; then
  echo "   └─ 💥 MalfunctionError: $failed of $count refused SIG$signal" >&2
  exit 1
fi
echo "   └─ ✨ sent SIG$signal to $count"
