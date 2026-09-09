#!/usr/bin/env bash
######################################################################
# .what = write the prune service + timer into this seat's user unit dir, and
#         enable the timer
#
# ⚠️ .why no early return on "the timer file exists"
#   - a PRESENCE test makes a unit WRITE-ONCE, so every later change to the
#     schedule or the age gate reaches no extant box, and the box reports
#     "already installed" while it drifts (`1.8.tmpfiles/provision.upsert.sh`)
#   - ⇒ the skip gate below reads CONTENT: `cmp` against the declared bytes,
#     the same comparison `provision.verify` makes
#
# ⚠️ .why `daemon-reload` before `enable --now`
#   - systemd caches unit files, so a rewrite with no reload leaves the OLD
#     definition live. the fix lands on disk and the box keeps its behavior
#
# .why sudo is asked for EXACTLY ONE step, and never for the units
#   - the units are USER units under `$HOME/.config/systemd/user`, and the
#     daemons they prune are this seat's own, so a camper writes them unaided
#   - LINGER is the lone exception, and only a sudo seat may set it. ground
#     sets it for every human seat, so a camper's own run finds it already true
#     (`term=seat`; `rule.require.seam-claims-have-an-owner`)
#
# guarantee:
#   - idempotent: both units are re-declared from one reader on every apply
#   - idempotent: `enable --now` converges on an already-enabled timer
#   - idempotent: linger is read before it is set, and set once per seat
#   - declines with 🌙, never ✋, when the skill is absent from this checkout
#   - declines with 🌙, never ✋, when this seat cannot grant linger
######################################################################

grove_provision_1_6_4_keyrackd_provision_upsert() {
  local unit_dir service_name timer_name skill timer_src
  unit_dir="$(grove_provision_1_6_4_keyrackd_unit_dir)"
  service_name="$(grove_provision_1_6_4_keyrackd_service_name)"
  timer_name="$(grove_provision_1_6_4_keyrackd_timer_name)"
  skill="$(grove_provision_1_6_4_keyrackd_skill)"
  timer_src="$GROVE_SRC/machine/$timer_name"

  ####################################################################
  # 0. the two inputs this phase cannot supply itself
  ####################################################################

  # the skill sits outside `src/`. `boot` pushes `--from .` so a booted grove
  # holds it; this fires on a box pushed by hand with `--from src`.
  # an unprunable box is a degradation, never a failed provision.
  if [[ ! -x "$skill" ]]; then
    echo "   🌙 no keyrack.daemon.prune skill at $skill"
    echo "      ⇒ the timer would fire against an absent command, so it is not"
    echo "        declared. the leaked-daemon pool stays unbounded on this box"
    return 0
  fi

  # the timer IS carried by `src/`, so its absence is this checkout's defect
  if [[ ! -f "$timer_src" ]]; then
    echo "   ✋ no $timer_name at $timer_src" >&2
    echo "      ⇒ this run's own checkout is incomplete" >&2
    return 1
  fi

  ####################################################################
  # 1. what is ALREADY true — read before any write
  ####################################################################
  local converged=1
  cmp -s "$timer_src" "$unit_dir/$timer_name" || converged=0
  grove_provision_1_6_4_keyrackd_service_text \
    | cmp -s - "$unit_dir/$service_name" || converged=0
  systemctl --user is-enabled "$timer_name" >/dev/null 2>&1 || converged=0
  systemctl --user is-active  "$timer_name" >/dev/null 2>&1 || converged=0
  grove_provision_1_6_4_keyrackd_lingers || converged=0

  if [[ "$converged" -eq 1 ]]; then
    echo "   • both units match this checkout, the timer is armed, and this seat lingers ✔"
    return 0
  fi

  ####################################################################
  # 2. declare both units — EVERY run, from the one reader
  ####################################################################
  mkdir -p "$unit_dir" || return 1

  # ⚠️ a plain redirect, never `rhx teesafe` — a grove links no repo role, so
  #    `rhx <skill>` resolves no skill there (rule.forbid.the-driver-by-path,
  #    carve-out 3). a bundle reaches for shell, and its own verify is the check
  grove_provision_1_6_4_keyrackd_service_text > "$unit_dir/$service_name" || {
    echo "   ✋ could not write $unit_dir/$service_name" >&2
    return 1
  }
  cp "$timer_src" "$unit_dir/$timer_name" || return 1
  echo "   • $service_name and $timer_name declared"

  ####################################################################
  # 3. reload FIRST — a rewrite with no reload does no work
  ####################################################################
  systemctl --user daemon-reload || {
    echo "   ✋ systemctl --user daemon-reload failed" >&2
    echo "      ⇒ the new unit files are on disk and the OLD definitions stay" >&2
    echo "        live, so the fix appears applied and the box does not change" >&2
    return 1
  }

  if systemctl --user enable --now "$timer_name"; then
    echo "   • $timer_name enabled and started (every 15m, --min-age $(grove_provision_1_6_4_keyrackd_min_age))"
  else
    echo "   ✋ could not enable $timer_name" >&2
    echo "      ⇒ the leaked-daemon pool grows unbounded, and its memory is ANON," >&2
    echo "        so it lands in swap rather than in reclaimable cache" >&2
    return 1
  fi

  ####################################################################
  # 4. LINGER — the one step a seat without sudo cannot take for itself
  #
  # 🛑 it is set for EVERY human seat, not merely this one. ground runs first
  #    (rule.require.one-command-provision), and it is the only seat that may
  #    grant this — so a camper-only grant would be a grant nobody can make.
  #    the roster is derived from the box, so no seat is hardcoded (`5.8.docker`)
  ####################################################################
  grove_provision_1_6_4_keyrackd_lingers && {
    echo "   • $USER already lingers, so the timer outlives a logout ✔"
    return 0
  }

  # a desktop session already holds the user manager up, so linger buys no
  # capability on a local tier — see the 🛑 in `provision.verify.sh`
  if [[ "$GROVE_ENV_SERVER" == local@* ]]; then
    echo "   🌙 linger not set, and on $GROVE_ENV_SERVER the desktop session"
    echo "      keeps the user manager up already"
    return 0
  fi

  bundle.root.owns "linger for this box's seats" \
    "$USER lingers=no; the timer dies at this seat's last logout" || return 0

  local seat uid shell
  while IFS=: read -r seat _ uid _ _ _ shell; do
    [[ "$uid" -ge 1000 && "$uid" -lt 65534 ]] || continue
    [[ "$shell" == *nologin* || "$shell" == *false ]] && continue

    # all three lines go to stdout, none to stderr — this is a LOOP, so a
    # stderr line could land under a different seat's message
    if sudo loginctl enable-linger "$seat" 2>/dev/null; then
      echo "   • $seat lingers, so its prune timer outlives a logout ✔"
    else
      echo "   🌙 could not set linger for $seat"
      echo "      ⇒ its timer still fires while a session is open, and stops at"
      echo "        that seat's last logout — on a grove, when the duct closes"
    fi
  done < <(getent passwd)
}
