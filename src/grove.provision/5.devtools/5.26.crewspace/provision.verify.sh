#!/usr/bin/env bash
######################################################################
# .what = prove crewspace is built from the repo's source, and that it can read
#         the compositor where this shell holds a session
#
# .why the read is context, never the verdict
#   - the binary and its stamp are what hold after a reboot
#     (`rule.require.judge-declared-state-not-live-state`)
#   - a shell from a duct or a tty has no wayland session, which is harmless
#
# guarantee:
#   - READ-ONLY: `get --capture` writes no file
######################################################################

grove_provision_5_26_crewspace_provision_verify() {
  grove_provision_5_26_crewspace_applies || return 0

  local bin stamp
  bin="$(grove_provision_5_26_crewspace_bin_at)"
  stamp="$(grove_provision_5_26_crewspace_stamp_at)"
  local fix="rhx grove.provision --what 5.26.crewspace --mode apply"

  if [[ ! -x "$bin" ]]; then
    echo "   ✋ ConstraintError: $bin is absent — crewspace is not built" >&2
    echo "      ⇒ the kitty snapshot records no workspace for any window" >&2
    echo "      fix: $fix" >&2
    return 1
  fi
  if [[ "$(cat "$stamp" 2>/dev/null)" != "$(grove_provision_5_26_crewspace_src_hash)" ]]; then
    echo "   ✋ ConstraintError: $bin was built from other source than the repo's" >&2
    echo "      fix: $fix" >&2
    return 1
  fi
  echo "   • binary built from the repo's source ✔"

  if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "   🌙 no wayland session in this shell — the live read is not tried"
    return 0
  fi
  local capture wins
  if ! capture="$(timeout 10 "$bin" get --capture 2>&1)"; then
    echo "   🌙 crewspace could not read the compositor from this shell:" >&2
    printf '%s\n' "$capture" | tail -n 3 | sed 's/^/      /' >&2
    return 0
  fi
  wins="$(printf '%s\n' "$capture" | grep -c '^win	' || true)"
  echo "   • reads the compositor now — $wins window(s) ✔"
}
