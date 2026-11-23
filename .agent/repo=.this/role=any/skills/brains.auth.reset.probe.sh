#!/usr/bin/env bash
######################################################################
# .what = run the usage-reset reader on one usage node, and show what jq said
#
# .why  = `_brains_auth_reset_line` sinks jq's stderr and prints
#         `? could not read the reset fields` on any failure, so a jq that
#         cannot parse the program reads the same as a node that lacks the
#         fields. this names which, with the jq version beside it
#
# usage:
#   rhx brains.auth.reset.probe                      # the cli's real-offer shape
#   rhx brains.auth.reset.probe --node '<json>' [--kind full|fable]
#   rhx brains.auth.reset.probe --from checkout      # read this checkout's copy, not ~/
#
# guarantee:
#   - READ-ONLY: no network, no account read; it runs the reader on the node given
######################################################################
set -uo pipefail

probe_help() {
  echo "brains.auth.reset.probe — run the usage-reset reader on one node, and show what jq said"
  echo ""
  echo "usage:"
  echo "  rhx brains.auth.reset.probe                      the cli's real-offer shape"
  echo "  rhx brains.auth.reset.probe --node '<json>' [--kind full|fable]"
  echo "  rhx brains.auth.reset.probe --from checkout      read this checkout's copy, not ~/"
  echo ""
  echo "options:"
  echo "  --node <json>      the usage node to read (default: the real-offer shape)"
  echo "  --kind full|fable  which reset row to read (default: full)"
  echo "  --from installed|checkout  whose reader runs (default: installed)"
}

node='{"juniper_tide":{"eligible":true,"in_experiment":true,"arm":"reset","available":true}}'
kind="full"
from="installed"
while [[ $# -gt 0 ]]; do
  # a value flag with no value refuses: `shift 2` past the last arg shifts naught,
  # so the loop would read the same flag forever
  [[ "$1" =~ ^--(node|kind|from|skill|repo|role)$ && $# -lt 2 ]] && {
    echo "✋ ConstraintError: $1 needs a value" >&2
    echo "   └─ fix: rhx brains.auth.reset.probe --help" >&2; exit 2; }
  case "$1" in
    --node) node="${2:-}"; shift 2 ;;
    --kind) kind="${2:-}"; shift 2 ;;
    --from) from="${2:-}"; shift 2 ;;
    --skill|--repo|--role) shift 2 ;;
    --help|-h) probe_help; exit 0 ;;
    *) echo "✋ ConstraintError: unknown arg: $1" >&2; echo "   └─ fix: rhx brains.auth.reset.probe --help" >&2; exit 2 ;;
  esac
done

file="$HOME/.bash_aliases.brains.auth.sh"
# the checkout's root is four dirs above this skill, never `git rev-parse`: a grove's pushed
#   checkout holds no `.git`, so a rev-parse there answers naught and the path loses its root
[[ "$from" == "checkout" ]] && file="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../../.." && pwd)/src/grove.provision/2.shell/2.7.aliases/brains.auth.sh"
[[ -f "$file" ]] || { echo "✋ ConstraintError: no reader at $file" >&2; exit 2; }

# shellcheck disable=SC1090
source "$file" >/dev/null 2>&1
declare -f _brains_auth_reset_line >/dev/null || { echo "✋ ConstraintError: $file defines no _brains_auth_reset_line" >&2; exit 2; }

# lift the jq program out of the function body, so it runs with stderr kept
prog="$(declare -f _brains_auth_reset_line | awk '/jq -r --arg kind/{f=1;sub(/.*jq -r --arg kind "\$kind" \x27/,"");print;next} f&&/^ *\x27 <<</{exit} f{print}')"

echo "🔬 brains.auth.reset.probe --kind $kind --from $from"
echo "   ├─ jq: $(command -v jq) · $(jq --version 2>&1)"
echo "   ├─ reader: $(_brains_auth_reset_line "$node" "$kind")"
err="$(jq -r --arg kind "$kind" "$prog" <<< "$node" 2>&1 >/dev/null)"
[[ -z "$err" ]] && { echo "   └─ jq stderr: (none) ✔"; exit 0; }
echo "   └─ jq stderr"
# each line jq said, a child branch under its label, the last one closed
awk '{ l[n++] = $0 } END { for (i = 0; i < n; i++) print "      " (i == n - 1 ? "└─ " : "├─ ") l[i] }' <<< "$err"
