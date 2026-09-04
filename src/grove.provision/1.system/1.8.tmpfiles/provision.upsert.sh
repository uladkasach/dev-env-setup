#!/usr/bin/env bash
######################################################################
# .what = install the /tmp cleanup service and timer, and enable the timer
#
# ⚠️ there is no early return on "the timer file exists"
#   - 📜 a return on `[[ -f "$timer_path" ]]` made the unit WRITE-ONCE
#   - every later change to the schedule or the find expression reached no extant box
#   - the box reported "already installed; skipped", so the drift was invisible
#   - ⇒ a file the installer only ever CREATES is a file the repo does not own
#
# ⚠️ .why `daemon-reload` before `enable --now`
#   - systemd caches unit files
#   - ⇒ a rewrite with no reload leaves the OLD definition live
#   - the fix lands on disk and the box keeps the broken behavior
#
# ⚠️ .why the units are COPIED, not heredoc'd through `sudo tee`
#   - `$GROVE_SRC/machine/tmp-cleanup.{service,timer}` are the declared bytes
#   - ⇒ `provision.verify` can DIFF the installed copy against them
#   - a heredoc can only ever write, never be compared
#   - (rule.require.judge-declared-state-not-live-state)
#
# guarantee:
#   - idempotent: the two files are COPIED from declared sources
#   - idempotent: `enable --now` converges on an already-enabled timer
######################################################################

grove_provision_1_8_tmpfiles_provision_upsert() {
  local unit_dir="/etc/systemd/system"

  ####################################################################
  # 0. what is ALREADY true — read before any privilege is asked for
  #
  # 🛑 read the box FIRST, assert root second
  #   - a grove's camper seat holds no sudo by design (`term=seat`)
  #   - 📜 root-first made every camper apply fail over two units `ground` had installed
  #   - see `bundle.root.declines` for the full measurement
  #
  # ⚠️ this is NOT the write-once defect the header warns about
  #   - that was a PRESENCE test, which passes on a stale unit
  #   - this reads CONTENT: `cmp` against the declared bytes, as `provision.verify` does
  #   - ⇒ a changed source still re-copies, and only a matched box is skipped
  #   - (`rule.require.judge-declared-state-not-live-state`)
  ####################################################################
  local name converged=1
  for name in tmp-cleanup.service tmp-cleanup.timer; do
    cmp -s "$GROVE_SRC/machine/$name" "$unit_dir/$name" || converged=0
  done
  systemctl is-enabled tmp-cleanup.timer >/dev/null 2>&1 || converged=0
  systemctl is-active tmp-cleanup.timer >/dev/null 2>&1 || converged=0

  if [[ "$converged" -eq 1 ]]; then
    echo "   • both units match this checkout, and the timer is enabled ✔"
    return 0
  fi

  # it does not hold, and this seat cannot set it — ground owns every write below
  if ! pkg_can_sudo; then
    bundle.root.declines "the /tmp cleanup units" \
      "$unit_dir holds them; timer is $(systemctl is-active tmp-cleanup.timer 2>/dev/null || echo inactive)"
    return 0
  fi

  # ⚠️ every write below is root's, and `sudo` reads a password from a TERMINAL
  #   - with none attached it prompts anyway
  #   - a duct is tmux, so the question sits on the pane and eats the next command sent
  #   - `pkg_install` asserts this already, but a bundle that reaches root DIRECTLY must ask itself
  #   - reached only when this seat CAN sudo, since the gate above returned otherwise
  pkg_assert_sudo || return 1

  ####################################################################
  # 1. the two units — each from a declared source, EVERY run
  ####################################################################
  local name
  for name in tmp-cleanup.service tmp-cleanup.timer; do
    local src="$GROVE_SRC/machine/$name"
    if [[ ! -f "$src" ]]; then
      echo "   ✋ no $name at $src" >&2
      echo "      ⇒ this run's own checkout is incomplete" >&2
      return 1
    fi
    sudo cp "$src" "$unit_dir/$name" || return 1
  done
  echo "   • tmp-cleanup.service and tmp-cleanup.timer declared"

  ####################################################################
  # 2. reload FIRST — see the header for why a rewrite alone does no work
  ####################################################################
  sudo systemctl daemon-reload || {
    echo "   ✋ systemctl daemon-reload failed" >&2
    echo "      ⇒ the new unit files are on disk and the OLD definitions stay" >&2
    echo "        live, so the fix appears applied and the box does not change" >&2
    return 1
  }

  if sudo systemctl enable --now tmp-cleanup.timer; then
    echo "   • tmp-cleanup.timer enabled and started (daily, 03:00)"
  else
    echo "   ✋ could not enable tmp-cleanup.timer" >&2
    echo "      ⇒ /tmp keeps its accumulation, so the boot-time walk stays slow" >&2
    return 1
  fi
}
