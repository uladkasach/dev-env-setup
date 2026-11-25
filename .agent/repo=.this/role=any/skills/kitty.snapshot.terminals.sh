#!/usr/bin/env bash
######################################################################
# .what = map every open kitty window to its shells, cwds, and the tmux
#         panes (default server AND every duct server) behind it
#
# .why  = a thin shim, so `rhx kitty.snapshot.terminals` reaches the ONE
#         implementation at `src/machine/kitty.snapshot.terminals.sh` — the
#         same file `4.3.4.snapshot` installs as `~/.local/bin/kitty.snap`
#
#         📜 measured 2026-11-24: this path held a full second copy that had
#         drifted behind `src/` — it read only the default tmux server, so
#         every duct window showed as `tmux: client ×N` with no pane cwds.
#         one implementation, one writer (`rule.forbid.two-writers-on-one-artifact`).
#
# usage:
#   rhx kitty.snapshot.terminals            # human tree (default)
#   rhx kitty.snapshot.terminals --json     # one json object per shell
#   rhx kitty.snapshot.terminals --save     # also persist to ~/.kitty/snaps
#
# guarantee:
#   - READ-ONLY, same as the file it calls
#   - fails loud if the checkout lacks the implementation
######################################################################

set -euo pipefail

skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
impl="$skill_dir/../../../../src/machine/kitty.snapshot.terminals.sh"

if [[ ! -f "$impl" ]]; then
  echo "💥 MalfunctionError: no snapper at $impl" >&2
  echo "   ⇒ this checkout is incomplete; the shim has naught to call" >&2
  exit 1
fi

exec bash "$impl" "$@"
