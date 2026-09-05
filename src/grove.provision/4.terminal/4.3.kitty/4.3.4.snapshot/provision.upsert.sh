#!/usr/bin/env bash
######################################################################
# .what = install the kitty snapper, the low-battery guard that calls it, and
#         the systemd user unit + timer that drive the guard
#
# .a USER timer, not a system one
#   - the snap must see the human's OWN kitty processes and `~/.kitty/snaps`
#   - a system unit fires as root, whose `$HOME` is `/root`
#   - ⇒ it would run correctly and snapshot the wrong box
#
# ⚠️ .`daemon-reload` before `enable --now`
#   - systemd caches unit files, so a rewrite alone leaves the OLD one live
#   - ⇒ the fix lands on disk and the box keeps the prior behavior
#
# .the files are COPIED from `$GROVE_SRC/machine/`, never heredoc'd here
#   - a heredoc makes this phase the only place the text exists
#   - a verify could then assert presence and never CURRENCY
#   - the declared-asset shape lets `provision.verify` prove the live guard current
#
# guarantee
#   - idempotent: the files are copied from declared sources
#   - `enable --now` converges on an already-enabled timer
#   - it DECLINES where no screen exists
######################################################################

grove_provision_4_3_4_snapshot_provision_upsert() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — the snap captures kitty WINDOWS, and $GROVE_ENV_SERVER"
    echo "      has none. its battery is a fiction too, so the guard would poll a"
    echo "      /sys path that is absent and exit 0 forever"
    return 0
  fi

  local bin_dir="$HOME/.local/bin"
  local unit_dir="$HOME/.config/systemd/user"
  mkdir -p "$bin_dir" "$unit_dir" || return 1

  ####################################################################
  # 1. the snapper, the guard, and the two units — each from a declared source
  #
  # ⚠️ `kitty.snapshot.terminals.sh` lands as `kitty.snap`, and it goes FIRST
  #   - both the guard and the `kitty.snap` shell alias call it by that path
  #   - it once lived only under `.agent/`, outside `src/`
  #   - so a box seeded by `git.grove.push --from src` got the timer and no file
  #   - (rule.require.bundles-own-their-dependencies)
  ####################################################################
  local pair
  for pair in \
    "kitty.snapshot.terminals.sh:$bin_dir/kitty.snap" \
    "kitty_snap_lowbatt:$bin_dir/kitty_snap_lowbatt" \
    "kitty_snap_lowbatt.service:$unit_dir/kitty_snap_lowbatt.service" \
    "kitty_snap_lowbatt.timer:$unit_dir/kitty_snap_lowbatt.timer"
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
  chmod +x "$bin_dir/kitty.snap" "$bin_dir/kitty_snap_lowbatt" || return 1
  echo "   • kitty.snap, the low-battery guard, and its two units declared"

  ####################################################################
  # 2. reload FIRST
  #   - the header says why a rewrite alone does no work
  ####################################################################
  systemctl --user daemon-reload || {
    echo "   ✋ systemctl --user daemon-reload failed" >&2
    echo "      ⇒ the new unit files are on disk and the OLD definitions stay" >&2
    echo "        live, so the fix appears applied and the box does not change" >&2
    return 1
  }

  if systemctl --user enable --now kitty_snap_lowbatt.timer; then
    echo "   • kitty_snap_lowbatt.timer enabled and started (polls every 3 min)"
  else
    echo "   ✋ could not enable kitty_snap_lowbatt.timer" >&2
    echo "      ⇒ no snap fires on a low battery, so the window/pwd map is lost" >&2
    echo "        the one time it is most expensive to lose — an unattended die" >&2
    return 1
  fi
}
