#!/usr/bin/env bash
######################################################################
# .what = show a process and every ancestor up to init, with the FULL argv
#
# .why  = a churn report names a parent by a truncated cmdline, and a
#         truncated wrapper (`zsh -c trap 'exec …' INT`) names no author.
#         the full argv, and who launched it, is what turns a name into a
#         file to fix — and the parent of a short-lived child outlives it
#
# usage:
#   rhx machine.process.lineage --pid 12345            # one pid, up to init
#   rhx machine.process.lineage --comm sleep --top 3   # newest 3 of a name
#
# guarantee:
#   - read-only: /proc reads only; no kill, no signal
#   - a pid that dies mid-read is reported as gone, never as an error
#   - exit 0 = reported · 2 = bad input
######################################################################
set -uo pipefail

pid="" comm="" top=3
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pid)  pid="${2:-}"; shift 2 ;;
    --comm) comm="${2:-}"; shift 2 ;;
    --top)  top="${2:-}"; shift 2 ;;
    # absorb harness-injected args; `rhx <skill>` prepends --repo/--role/--skill
    --repo|--role|--skill) shift 2 ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) echo "✋ ConstraintError: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

# reject absent or malformed input
[[ -n "$pid" || -n "$comm" ]] || { echo "✋ ConstraintError: --pid or --comm is required" >&2; exit 2; }
[[ -z "$pid" || "$pid" =~ ^[0-9]+$ ]] || { echo "✋ ConstraintError: --pid must be a number" >&2; exit 2; }
[[ "$top" =~ ^[0-9]+$ ]] || { echo "✋ ConstraintError: --top must be a number" >&2; exit 2; }

# .what = the full argv of one pid, NUL-split into spaces; empty if gone
__lineage_argv() { tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null; }

# .what = the parent pid of one pid; empty if gone
__lineage_ppid() { awk '/^PPid:/ { print $2 }' "/proc/$1/status" 2>/dev/null; }

# .what = print one pid and its ancestors, root last
__lineage_chain() {
  local cur="$1" depth=0 argv parent
  echo "   ├─ pid $cur"
  while [[ -n "$cur" && "$cur" != 0 && $depth -lt 40 ]]; do
    argv="$(__lineage_argv "$cur")"
    if [[ -z "$argv" && ! -d "/proc/$cur" ]]; then
      echo "   │  └─ (gone before it could be read)"
      return 0
    fi
    printf '   │  %s%-8s %s\n' "$(printf '%*s' $((depth * 2)) '')" "$cur" "${argv:-[$(cat "/proc/$cur/comm" 2>/dev/null)]}"
    [[ "$cur" == 1 ]] && break
    parent="$(__lineage_ppid "$cur")"
    cur="$parent"
    depth=$((depth + 1))
  done
}

echo "🐈 heres the lineage..."
echo "   │"

# one named pid
if [[ -n "$pid" ]]; then
  __lineage_chain "$pid"
  echo "   └─ done"
  exit 0
fi

# the newest members of a comm — newest first, since a churner's live ones are young
pids="$(pgrep -n -x "$comm" ; pgrep -x "$comm" | sort -rn | head -n "$top")"
pids="$(printf '%s\n' "$pids" | awk 'NF && !seen[$0]++' | head -n "$top")"
if [[ -z "$pids" ]]; then
  echo "   └─ no live '$comm' process"
  exit 0
fi
for p in $pids; do __lineage_chain "$p"; done
echo "   └─ done"
