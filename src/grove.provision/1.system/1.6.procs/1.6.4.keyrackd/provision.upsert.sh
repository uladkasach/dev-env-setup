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
# .why this phase asks no sudo at all
#   - the units are USER units under `$HOME/.config/systemd/user`, and the
#     daemons they prune are this seat's own, so a camper writes them unaided
#   - LINGER, which this timer needs to outlive the duct, is owned by
#     `1.6.7.linger`: it runs first in `1.6.procs` and grants it to every seat
#     (`rule.require.seam-claims-have-an-owner`)
#
# guarantee:
#   - idempotent: both units are re-declared from one reader on every apply
#   - idempotent: `enable --now` converges on an already-enabled timer
#   - declines with 🌙, never ✋, when the skill is absent from this checkout
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
    echo "   ✋ ConstraintError: no $timer_name at $timer_src" >&2
    echo "      ⇒ this run's own checkout is incomplete" >&2
    return 1
  fi

  ####################################################################
  # 1. what is ALREADY true — read before any write
  ####################################################################
  # a read: a unit cmp cannot read is simply not converged, so cmp's own complaint is not news
  local converged=1
  cmp -s "$timer_src" "$unit_dir/$timer_name" 2>/dev/null || converged=0
  grove_provision_1_6_4_keyrackd_service_matches "$unit_dir/$service_name" || converged=0
  systemctl --user is-enabled "$timer_name" >/dev/null 2>&1 || converged=0
  systemctl --user is-active  "$timer_name" >/dev/null 2>&1 || converged=0

  if [[ "$converged" -eq 1 ]]; then
    echo "   • both units match this checkout, and the timer is armed ✔"
    return 0
  fi

  ####################################################################
  # 2. declare both units — EVERY run, from the one reader
  ####################################################################
  # each write's own complaint rides inside its ✋ as the cause, never as a bare line above it
  local write_err
  write_err="$(LC_ALL=C mkdir -p "$unit_dir" 2>&1)" || {
    echo "   ✋ ConstraintError: could not make $unit_dir" >&2
    echo "      cause: ${write_err#mkdir: }" >&2
    return 1
  }

  # ⚠️ a plain redirect, never `rhx teesafe` — a grove links no repo role, so
  #    `rhx <skill>` resolves no skill there (rule.forbid.the-driver-by-path,
  #    carve-out 3). a bundle reaches for shell, and its own verify is the check
  # the shell's redirect complaint reads `bash: line N: <path>: <why>`; the header names the
  #   path, so the cause keeps only the why
  write_err="$( { LC_ALL=C grove_provision_1_6_4_keyrackd_service_text > "$unit_dir/$service_name"; } 2>&1 )" || {
    echo "   ✋ ConstraintError: could not write $unit_dir/$service_name" >&2
    echo "      cause: ${write_err##*: }" >&2
    return 1
  }
  write_err="$(LC_ALL=C cp "$timer_src" "$unit_dir/$timer_name" 2>&1)" || {
    echo "   ✋ ConstraintError: could not write $unit_dir/$timer_name" >&2
    echo "      cause: ${write_err#cp: }" >&2
    return 1
  }
  echo "   • $service_name and $timer_name declared"

  ####################################################################
  # 3. reload FIRST — a rewrite with no reload does no work
  ####################################################################
  systemctl --user daemon-reload || {
    echo "   ✋ ConstraintError: systemctl --user daemon-reload failed" >&2
    echo "      ⇒ the new unit files are on disk and the OLD definitions stay" >&2
    echo "        live, so the fix appears applied and the box does not change" >&2
    return 1
  }

  if systemctl --user enable --now "$timer_name"; then
    echo "   • $timer_name enabled and started (every 15m, --min-age $(grove_provision_1_6_4_keyrackd_min_age))"
  else
    echo "   ✋ ConstraintError: could not enable $timer_name" >&2
    echo "      ⇒ the leaked-daemon pool grows unbounded, and its memory is ANON," >&2
    echo "        so it lands in swap rather than in reclaimable cache" >&2
    return 1
  fi
}
