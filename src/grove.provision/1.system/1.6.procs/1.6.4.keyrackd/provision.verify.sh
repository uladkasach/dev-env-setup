#!/usr/bin/env bash
######################################################################
# .what = prove both units on this seat match THIS checkout, and that the timer
#         is enabled and live
#
# 🛑 .why it diffs bytes rather than tests presence
#   - a unit file that exists says the installer ran ONCE, and says none of what
#     it holds. every change to the schedule or the age gate is invisible to a
#     presence test (rule.require.judge-declared-state-not-live-state)
#   - the service's declared bytes come from the SAME reader the upsert writes
#     from, so the two halves cannot cut the set their own way
#
# ⚠️ .why an enabled timer is not enough
#   - `is-enabled` reports the INSTALL symlink; `is-active` reports whether the
#     timer is armed on this boot. a timer enabled and inactive fires never, and
#     the pool grows with no signal
#
# 🛑 .why LINGER is a claim of its own, and the one a grove turns on
#   - both readers above answer from INSIDE a live user manager. on a grove that
#     manager exists only because a duct is open, so both say ✔ right up to the
#     moment the pane closes and the manager dies with the session
#   - ⇒ a green `is-active` on a grove is a fact about the OBSERVER's session,
#     never about the box. linger is what makes it a fact about the box
#     (`gotcha.a-check-that-cries-wolf-gets-silenced`, q1)
######################################################################

grove_provision_1_6_4_keyrackd_provision_verify() {
  local unit_dir service_name timer_name skill timer_src claims=0
  unit_dir="$(grove_provision_1_6_4_keyrackd_unit_dir)"
  service_name="$(grove_provision_1_6_4_keyrackd_service_name)"
  timer_name="$(grove_provision_1_6_4_keyrackd_timer_name)"
  skill="$(grove_provision_1_6_4_keyrackd_skill)"
  timer_src="$GROVE_SRC/machine/$timer_name"

  # the upsert declines when the skill is absent, so the verify claims none
  # either — a claim this box was never offered is not a claim it failed
  if [[ ! -x "$skill" ]]; then
    echo "   🌙 no prune skill on this box, so no timer is claimed"
    return 0
  fi

  ####################################################################
  # 1. the service — declared bytes vs installed bytes
  ####################################################################
  if grove_provision_1_6_4_keyrackd_service_text | cmp -s - "$unit_dir/$service_name"; then
    echo "   • $service_name matches this checkout ✔"
  else
    echo "   ✋ $unit_dir/$service_name does NOT match this checkout" >&2
    echo "      ⇒ the timer fires an ExecStart this repo did not declare —" >&2
    echo "        an old skill path, or an old --min-age gate" >&2
    echo "      fix: rhx grove.provision --what 1.6.4.keyrackd --mode apply" >&2
    claims=$((claims + 1))
  fi

  ####################################################################
  # 2. the timer — declared bytes vs installed bytes
  ####################################################################
  if cmp -s "$timer_src" "$unit_dir/$timer_name"; then
    echo "   • $timer_name matches this checkout ✔"
  else
    echo "   ✋ $unit_dir/$timer_name does NOT match $timer_src" >&2
    echo "      ⇒ the prune runs on a cadence this repo did not declare" >&2
    echo "      fix: rhx grove.provision --what 1.6.4.keyrackd --mode apply" >&2
    claims=$((claims + 1))
  fi

  ####################################################################
  # 3. enabled AND active — see the ⚠️ in the header for why both
  ####################################################################
  if systemctl --user is-enabled "$timer_name" >/dev/null 2>&1; then
    echo "   • $timer_name is enabled ✔"
  else
    echo "   ✋ $timer_name is not enabled" >&2
    echo "      ⇒ it will not survive a reboot, so the pool refills unwatched" >&2
    echo "      fix: systemctl --user enable --now $timer_name" >&2
    claims=$((claims + 1))
  fi

  if systemctl --user is-active "$timer_name" >/dev/null 2>&1; then
    echo "   • $timer_name is armed on this boot ✔"
  else
    echo "   ✋ $timer_name is not armed" >&2
    echo "      ⇒ enabled and inactive means it fires never, and the daemon" >&2
    echo "        pool grows with no signal until the box reaches swap" >&2
    echo "      fix: systemctl --user start $timer_name" >&2
    claims=$((claims + 1))
  fi

  ####################################################################
  # 4. linger — the only claim above that outlives this session
  #
  # 🛑 .why this is a 🌙 on a local tier and a ✋ on a cloud one
  #   - it is the exact INVERSE of `1.6.2.monitor`'s gate: that leaf needs a
  #     desktop bus, so it declines on cloud. this one needs a session that
  #     PERSISTS, which a desktop already supplies for free
  #   - on `local@unix` the graphical session holds the user manager up for as
  #     long as the box is awake, so linger buys no capability. a ✋ there would
  #     go red on a box where the timer plainly runs — and a check seen to cry
  #     wolf gets silenced, taking the grove's real ✋ down with it
  #     (`gotcha.a-check-that-cries-wolf-gets-silenced`)
  ####################################################################
  if grove_provision_1_6_4_keyrackd_lingers; then
    echo "   • $USER lingers, so the timer outlives a logout ✔"
  elif [[ "$GROVE_ENV_SERVER" == local@* ]]; then
    echo "   🌙 $USER does not linger, and on $GROVE_ENV_SERVER that costs none"
    echo "      ⇒ a desktop session keeps the user manager up already. the claim"
    echo "        is a ✋ on a cloud grove, whose only login is the duct"
  else
    echo "   ✋ $USER does not linger" >&2
    echo "      ⇒ this seat's user manager dies at its last logout, and every" >&2
    echo "        claim above dies with it. on a grove that logout is the duct's" >&2
    echo "        last pane, so the prune runs while somebody watches and never" >&2
    echo "        otherwise" >&2
    echo "      fix: run this bundle from the seat WITH sudo — only it may grant" >&2
    echo "           linger, and it grants it for every seat on the box" >&2
    claims=$((claims + 1))
  fi

  [[ "$claims" -eq 0 ]]
}
