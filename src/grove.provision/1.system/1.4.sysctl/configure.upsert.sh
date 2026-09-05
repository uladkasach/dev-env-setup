#!/usr/bin/env bash
######################################################################
# .what = declare the two raised kernel parameters, then reload sysctl so they take
#         without a reboot
#
# .the two keys
#   - `fs.inotify.max_user_watches = 524288` — the stock 8192 is under any real watcher
#   - nvim's LSP, a dev server, `tsc --watch`, and a watch-mode test runner all exceed it
#   - the failure is `ENOSPC`, which prints as "no space left on device"
#   - ⇒ a human diagnoses a full disk on a box with terabytes free
#   - per https://stackoverflow.com/a/32600959/3068233
#   - `vm.swappiness = 10` — biases the kernel toward RAM and makes it reach for swap late
#   - the stock 60 pages out a live process while cache sits resident
#   - ref: https://wiki.debian.org/swappiness
#
# .why appended only when ABSENT
#   - sysctl reads the LAST assignment of a key
#   - ⇒ an unconditional append grows the file by two lines on every run
#   - that is functionally idempotent and textually not
#   - after twenty runs the file holds forty lines and no human can tell which is live
#
# .why `sysctl -p` and not a reboot
#   - `-p` applies the file to the live kernel now
#   - ⇒ the declaration and its effect converge in the same run
#   - that is what lets this bundle's verify check the LIVE value
#
# guarantee:
#   - idempotent: each key is appended only when absent
#   - idempotent: the reload re-applies the same file
######################################################################

grove_provision_1_4_sysctl_configure_upsert() {
  ####################################################################
  # 0. what is ALREADY true — read before any privilege is asked for
  #
  # 🛑 read the box FIRST, assert root second
  #   - a grove's camper seat holds no sudo by design (`term=seat`)
  #   - 📜 root-first made every camper apply fail over two keys `ground` had declared
  #   - see `bundle.root.declines` for the full measurement
  #
  # .why BOTH the file and the LIVE kernel are read
  #   - this bundle claims the keys are declared AND live, which is why it runs `sysctl -p`
  #   - ⇒ a read of the file alone would skip a box whose live kernel disagrees
  #   - every read here is free: `grep` on a world-readable file, and `sysctl -n`
  ####################################################################
  local live_watches live_swappiness
  live_watches="$(sysctl -n fs.inotify.max_user_watches 2>/dev/null || true)"
  live_swappiness="$(sysctl -n vm.swappiness 2>/dev/null || true)"

  if grep -q '^fs.inotify.max_user_watches=524288$' /etc/sysctl.conf 2>/dev/null \
    && grep -q '^vm.swappiness=10$' /etc/sysctl.conf 2>/dev/null \
    && [[ "$live_watches" == "524288" && "$live_swappiness" == "10" ]]; then
    echo "   • both sysctl keys already declared and live ✔"
    return 0
  fi

  # it does not hold, and this seat cannot set it — ground owns every write below
  if ! pkg_can_sudo; then
    bundle.root.declines "the sysctl tunables" \
      "live: max_user_watches=${live_watches:-?}, swappiness=${live_swappiness:-?}"
    return 0
  fi

  # ⚠️ every write below is root's, and `sudo` reads a password from a TERMINAL
  #   - with none attached it prompts anyway
  #   - a duct is tmux, so the question sits on the pane and eats the next command sent
  #   - `pkg_install` asserts this already, but a bundle that reaches root DIRECTLY must ask itself
  #   - reached only when this seat CAN sudo, since the gate above returned otherwise
  pkg_assert_sudo || return 1

  if grep -q '^fs.inotify.max_user_watches=' /etc/sysctl.conf; then
    echo "   • inotify watch limit already declared"
  else
    echo 'fs.inotify.max_user_watches=524288' | sudo tee -a /etc/sysctl.conf >/dev/null
    echo "   • inotify watch limit declared"
  fi

  if grep -q '^vm.swappiness=' /etc/sysctl.conf; then
    echo "   • swappiness already declared"
  else
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf >/dev/null
    echo "   • swappiness declared"
  fi

  ####################################################################
  # apply to the LIVE kernel, so the declaration and its effect converge now
  #
  # .why this is a named failure and NOT a bare `|| return 1`
  #   - a single bad line ANYWHERE in sysctl.conf aborts the whole file
  #   - ⇒ `sysctl -p` fails for reasons unrelated to the two keys above
  #   - a bare `return 1` gives no hint the cause is somebody else's line
  #   - (rule.require.failloud)
  ####################################################################
  if ! sudo sysctl -p >/dev/null; then
    echo "   ✋ sysctl -p refused /etc/sysctl.conf" >&2
    echo "      ⇒ the two keys above ARE declared on disk, so they will take on the" >&2
    echo "        next boot. what failed is the LIVE reload" >&2
    echo "      ⇒ a single bad line anywhere in sysctl.conf aborts the whole file," >&2
    echo "        so the cause is usually NOT one of the two keys this bundle owns" >&2
    echo "      read why: sudo sysctl -p    # it names the line at fault" >&2
    return 1
  fi

  echo "   • sysctl reloaded — both keys are live now"
}
