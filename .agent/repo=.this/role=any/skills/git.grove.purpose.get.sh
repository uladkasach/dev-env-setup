#!/usr/bin/env bash
######################################################################
# .what = read a grove's purpose marker EXACTLY as the crew boot gate reads it
#
# .why  = `__crew_grove_purpose` (ehmpathy/rhachet-roles-bhuild crewwork.sh) asks
#         the box over ssh, bounded and non-interactive, and takes the first line
#         of `~/.grove/purpose` with all whitespace cut. a read by any other road
#         (the duct, another seat, a login shell) can disagree with what a sprout
#         meets. this one rides the gate's own transport, so its answer IS the
#         gate's answer
#
# usage:
#   rhx git.grove.purpose.get <grove>
#
# guarantee:
#   - READ-ONLY: one bounded ssh (BatchMode, ConnectTimeout=5), no write
#   - prints `work`, `lab`, or `(none)` — `(none)` is where the gate falls to its
#     declared list, and off that list fails closed
#   - exit 0 = a marker was read · 1 = the ssh failed · 2 = bad input · 3 = no marker
######################################################################

set -uo pipefail

main() {
  local grove=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        echo "🏷️ git.grove.purpose.get — read a grove's purpose as the crew boot gate does"
        echo ""
        echo "usage:"
        echo "  rhx git.grove.purpose.get <grove>"
        echo ""
        echo "example:"
        echo "  rhx git.grove.purpose.get grove-1"
        return 0 ;;
      --repo|--role|--skill) shift 2 ;;
      -*) echo "✋ ConstraintError: unknown flag: $1" >&2; echo "   fix: rhx git.grove.purpose.get --help" >&2; return 2 ;;
      *)
        if [[ -n "$grove" ]]; then echo "✋ ConstraintError: name ONE grove" >&2; return 2; fi
        grove="$1"; shift ;;
    esac
  done
  if [[ -z "$grove" ]]; then
    echo "✋ ConstraintError: name a grove" >&2
    echo "   fix: rhx git.grove.purpose.get <grove>" >&2
    return 2
  fi

  # the gate's exact read: same flags, same remote command
  local raw rc=0
  raw="$(ssh -n -o BatchMode=yes -o ConnectTimeout=5 "$grove" \
    "sh -c 'cat ~/.grove/purpose 2>/dev/null | head -1'" 2>/dev/null)" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    echo "💥 MalfunctionError: ssh to $grove failed (rc $rc), so the gate reads no marker either" >&2
    echo "   read why: rhx git.grove.ready.verify $grove" >&2
    return 1
  fi
  local purpose="${raw//[[:space:]]/}"

  echo "🏷️ git.grove.purpose.get $grove"
  echo "   ├─ read: ssh -n -o BatchMode=yes -o ConnectTimeout=5 $grove (the gate's road)"
  if [[ -z "$purpose" ]]; then
    echo "   └─ purpose: (none) — the gate falls to its declared list, else fails closed"
    echo "      fix: rhx git.grove.send $grove --what 'env -C git/more/dev-env-setup rhx grove.provision --what 5.25.purpose --mode apply'"
    return 3
  fi
  echo "   └─ purpose: $purpose"
}

main "$@"
