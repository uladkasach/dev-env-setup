#!/usr/bin/env bash
######################################################################
# .what = install the monitor daemon, its systemd user unit, and its timer
#
# .why a USER timer, not a system one
#   - the alert goes to a human's session bus
#   - only the user's own systemd instance shares that bus
#   - ⇒ a system unit would fire as root, where `notify-send` has no session to speak to
#   - it would run correctly and reach nobody
#
# ⚠️ .why `daemon-reload` before `enable --now`
#   - systemd caches unit files
#   - ⇒ a rewrite with no reload leaves the OLD definition live
#   - the fix lands on disk and the box keeps the broken behavior
#   - that is the "config arrived, capacity did not" split this repo's verifies catch
#
# guarantee:
#   - idempotent: the three files are COPIED from declared sources
#   - idempotent: `enable --now` converges on an already-enabled timer
#   - it DECLINES where no notification bus exists
######################################################################

grove_provision_1_6_2_monitor_provision_upsert() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — the monitor alerts through notify-send, and"
    echo "      $GROVE_ENV_SERVER has no notification bus to alert onto."
    echo "      the finders themselves DO install here (1.6.1.finders)"
    return 0
  fi

  ####################################################################
  # 0. the sink this bundle alerts THROUGH
  #
  # ⚠️ this bundle OWNS `libnotify-bin` (`rule.require.bundles-own-their-dependencies`)
  #   - 📜 with the install absent, the monitor armed itself where every alert is discarded
  #   - and it reported ✔
  #   - it belongs here, not in `2.1.toolkit`, since this is the bundle that needs it
  #   - the toolkit is the shared floor, and a sink one bundle alerts through is its own
  #   - a grove declines above, so it is owed no notification bus at all
  #
  # .why `logger` is asserted in the verify but not installed here
  #   - it ships in `bsdutils`, which is essential on every debian box
  #   - ⇒ an install line would be a claim that can never be false
  #   - the verify still ASKS, since that belief is about the platform and costs one `command -v`
  ####################################################################
  if ! pkg_install libnotify-bin; then
    echo "   ✋ libnotify-bin did not install, so notify-send is absent" >&2
    echo "      ⇒ the monitor's whole output path is the desktop toast; without" >&2
    echo "        it the timer runs and every alert it raises reaches no one" >&2
    echo "      read why: sudo apt-get install libnotify-bin" >&2
    return 1
  fi

  local bin_dir="$HOME/.local/bin"
  local unit_dir="$HOME/.config/systemd/user"
  mkdir -p "$bin_dir" "$unit_dir" || return 1

  ####################################################################
  # 1. the daemon, and the two units — each from a declared source
  ####################################################################
  local pair
  for pair in \
    "machine_resource_procs_monitor:$bin_dir/machine_resource_procs_monitor" \
    "runaway_monitor.service:$unit_dir/runaway_monitor.service" \
    "runaway_monitor.timer:$unit_dir/runaway_monitor.timer"
  do
    local name="${pair%%:*}"
    local dst="${pair#*:}"
    local src="$GROVE_SRC/machine/$name"

    if [[ ! -f "$src" ]]; then
      echo "   ✋ no $name at $src" >&2
      echo "      ⇒ this run's own checkout is incomplete" >&2
      return 1
    fi
    cp "$src" "$dst" || return 1
  done
  chmod +x "$bin_dir/machine_resource_procs_monitor" || return 1
  echo "   • monitor daemon and its two units declared"

  ####################################################################
  # 2. reload FIRST — see the header for why a rewrite alone does no work
  ####################################################################
  systemctl --user daemon-reload || {
    echo "   ✋ systemctl --user daemon-reload failed" >&2
    echo "      ⇒ the new unit files are on disk and the OLD definitions stay" >&2
    echo "        live, so the fix appears applied and the box does not change" >&2
    return 1
  }

  if systemctl --user enable --now runaway_monitor.timer; then
    echo "   • runaway_monitor.timer enabled and started"
  else
    echo "   ✋ could not enable runaway_monitor.timer" >&2
    echo "      ⇒ no check runs on a schedule, so a runaway is found only when" >&2
    echo "        a human already noticed the box was slow" >&2
    return 1
  fi
}
