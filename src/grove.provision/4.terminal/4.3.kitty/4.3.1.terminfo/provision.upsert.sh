#!/usr/bin/env bash
# .what = make the `xterm-kitty` terminfo entry EXIST on this machine
# .why
#   - kitty advertises TERM=xterm-kitty; the entry ships in kitty's own package
#   - a box that never installed kitty does not hold it
#   - absent, tmux refuses to start, nvim/less garble, backspace draws as a space
#   - .refs = gotcha.4-3-kitty.demo=absent-terminfo-three-symptoms
# .why the debian package, not a `tic` fallback into ~/.terminfo
#   - a per-user copy leaves a second account on the same box broken
#   - its hand-written cap subset misbehaves on a cap it omits
#
# guarantee
#   - idempotent: a re-run on a box that holds the entry is a no-op

grove_provision_4_3_1_terminfo_provision_upsert() {
  # infocmp ships in ncurses-bin, absent on a minimal image; absent it, the
  # check below reads FALSE regardless of state
  if ! command -v infocmp >/dev/null 2>&1; then
    pkg_install ncurses-bin || return 1
    echo "   • ncurses-bin installed — this box shipped without infocmp"
  fi

  # reads where the entry RESOLVES FROM, never a proxy — a per-user
  # ~/.terminfo copy would read ✔ while a second account stays broken, and an
  # unconditional install would ask root over a fact ncurses-term may already
  # hold, a ✋ on the seat with no sudo
  local from; from="$(infocmp -1 xterm-kitty 2>/dev/null | grep -o '/[^ ]*terminfo[^ ]*' | head -1)"

  case "$from" in
    "$HOME"/*) ;;                      # per-user only — a second account is unserved
    "")        ;;                      # no path read, so no claim of system-wide reach
    *)         echo "   • xterm-kitty already served box-wide (at $from) — no work"
               return 0 ;;
  esac

  pkg_install kitty-terminfo
}
