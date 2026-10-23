#!/usr/bin/env bash
######################################################################
# .what = every human seat on a grove LINGERS: its user manager, and each
#         `systemd-run --user` scope a crew lives in, outlives its last logout
#
# .why it is a bundle of its own, and no longer a step of `1.6.4.keyrackd`
#   - linger is a fact about the SEAT, and every user unit on the box leans on
#     it — the prune timer, the abandoned reaper, and every crew's scope
#   - as a step inside keyrackd it had three defects (.refs = 1.vision, F5):
#     · it was skipped whenever the prune skill was absent from the checkout
#     · it answered ✔ once `$USER` lingered, and never read another seat
#     · a failed grant was a 🌙, so a seat could lack linger with no ✋ at all
#   - ⇒ here every seat is read on every apply, and a gap is a ✋ per seat
#
# .why it runs FIRST in `1.6.procs`
#   - every later leaf that asks `systemctl --user` reads a manager that only
#     linger keeps alive on a grove, whose one login is the duct
#
# .why every tier, the laptop included
#   - linger is a logind record, and logind runs on every kind; no physical
#     fact parts a laptop from a grove here (`rule.forbid.divergence-without-a-physical-reason`)
#   - a laptop's timers and crew scopes outlive its desktop session only with it
#
# usage:
#   rhx grove.provision --what 1.6.7.linger --mode plan
#   sudo -v && rhx grove.provision --what 1.6.7.linger --mode apply
######################################################################

# .what = where logind records a linger grant, one empty file per seat
# .why  = overridable, so a clamp can read a fixture dir rather than the box
grove_provision_1_6_7_linger_dir() {
  printf '%s' "${GROVE_LINGER_DIR:-/var/lib/systemd/linger}"
}

# .what = the HUMAN seats on this box, one name per line
# .why  = derived from the box, so no seat is hardcoded (`5.8.docker`)
#   - uid 1000..65533, and a shell that is neither nologin nor false
#   - `GROVE_LINGER_PASSWD` names a passwd-shaped fixture file for a clamp
grove_provision_1_6_7_linger_roster() {
  local seat uid shell
  while IFS=: read -r seat _ uid _ _ _ shell; do
    [[ "$uid" =~ ^[0-9]+$ ]] || continue
    [[ "$uid" -ge 1000 && "$uid" -lt 65534 ]] || continue
    [[ "$shell" == *nologin* || "$shell" == *false ]] && continue
    printf '%s\n' "$seat"
  done < <(grove_provision_1_6_7_linger_passwd)
}

# .what = the passwd rows the roster reads — a fixture file if one is named
grove_provision_1_6_7_linger_passwd() {
  [[ -n "${GROVE_LINGER_PASSWD:-}" ]] && { cat "$GROVE_LINGER_PASSWD"; return; }
  getent passwd
}

# .what = does this one seat linger?
# .why  = ONE reader, asked by both halves of this bundle; no other bundle
#   reads linger, so a grant can never be judged two ways
# ⚠️ the logind record, never `loginctl show-user` — that FAILS for a seat with
#    no session, so it cannot tell "no linger" from "no session" for another seat
grove_provision_1_6_7_linger_seat_lingers() {
  [[ -e "$(grove_provision_1_6_7_linger_dir)/$1" ]]
}

# .what = the seats that do NOT linger, one per line (empty = converged)
grove_provision_1_6_7_linger_unlingered() {
  local seat
  while read -r seat; do
    [[ -n "$seat" ]] || continue
    grove_provision_1_6_7_linger_seat_lingers "$seat" || printf '%s\n' "$seat"
  done < <(grove_provision_1_6_7_linger_roster)
}

grove_provision_1_6_7_linger() {
  bundle.upgrade 1.6.7.linger.provision.upsert
  bundle.upgrade 1.6.7.linger.provision.verify
}
