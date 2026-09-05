#!/usr/bin/env bash
######################################################################
# .what = prove kitty is present AND USABLE at the pinned version
#
# .why  = "present" is not the declaration, and this repo has the receipt: on
#         2026-07-29 `rhx` was present, on PATH, reachable from a login shell —
#         and threw on `--version`. every presence check passed on a binary that
#         cannot run. so a verify that stops at `command -v` proves close to
#         zero.
#
#         kitty has three ways to be present and broken, and each gets a claim:
#           1. the WRONG VERSION — an apt kitty 0.32 that shadows the tarball is
#              the exact defect `install_kitty` exists to prevent (kitty#7136:
#              spurious key-release events → doubled keys in nvim)
#           2. a SHADOWED symlink — /usr/bin/kitty ahead of /usr/local/bin/kitty
#              on PATH means the tarball is installed and unreachable
#           3. an absent `kitten` — remote control (`kitten @`) is half the reason
#              kitty was chosen over flatpak, and it is a separate binary
#
# .why it does NOT check the terminfo entry
#         `xterm-kitty` is subbundle 4.3.1's claim, not this one. that entry is
#         needed on every machine a kitty CONNECTS TO, which is usually not the
#         machine kitty runs on — so a check here would assert a claim about the
#         wrong box.
#
# guarantee:
#   - READ-ONLY. it runs version flags only and repairs no state
#
# exit:
#   0 = the pinned kitty and its kitten both run, from the expected path
#   1 = one of the three claims failed, and which is named
######################################################################

grove_provision_4_3_2_emulator_provision_verify() {
  local want="0.47.4" failed=0

  ####################################################################
  # 1. the binary runs, at the pinned version
  ####################################################################
  local have=""
  have="$(kitty --version 2>/dev/null | awk '{print $2}')"

  if [[ -z "$have" ]]; then
    echo "   ✋ kitty does not run (absent, or present and broken)" >&2
    echo "      fix: rhx grove.provision --what 4.3.2.emulator --mode apply" >&2
    return 1
  fi

  if [[ "$have" != "$want" ]]; then
    echo "   ✋ kitty runs at $have, but $want is declared" >&2
    echo "      ⇒ a kitty below 0.35 emits spurious key-release events, which" >&2
    echo "        nvim counts as double presses (kitty#7136). that is the whole" >&2
    echo "        reason this entry pins a tarball instead of apt." >&2
    failed=$(( failed + 1 ))
  else
    echo "   • kitty $have runs ✔"
  fi

  ####################################################################
  # 2. the binary that runs is the TARBALL one, not an apt kitty in front of it
  #
  # .why this claim is separate from 1: apt and the tarball could momentarily
  #      agree on a version, and a shadowed install would still break on the next
  #      pin bump. the PATH resolution is its own declaration.
  ####################################################################
  local from; from="$(command -v kitty 2>/dev/null)"
  local real; real="$(readlink -f "${from:-/dev/null}" 2>/dev/null)"
  case "$real" in
    /opt/kitty.app/*) echo "   • it is the tarball build ✔ ($from → $real)" ;;
    "")               echo "   ✋ kitty is not on PATH at all" >&2
                      failed=$(( failed + 1 )) ;;
    *)                echo "   ✋ the kitty on PATH is NOT the tarball build" >&2
                      echo "      on PATH: $from → $real" >&2
                      echo "      ⇒ /opt/kitty.app sits behind it, so the pin is moot" >&2
                      echo "      fix: sudo apt remove kitty -y, then re-drive this bundle" >&2
                      failed=$(( failed + 1 )) ;;
  esac

  ####################################################################
  # 3. `kitten` runs too — remote control is half of why kitty was chosen
  ####################################################################
  if kitten --version >/dev/null 2>&1; then
    echo "   • kitten runs ✔ (remote control is reachable)"
  else
    echo "   ✋ kitten does not run" >&2
    echo "      ⇒ no 'kitten @' remote control, so every termwork skill that" >&2
    echo "        drives a window or tab is dead on this machine" >&2
    failed=$(( failed + 1 ))
  fi

  [[ "$failed" -eq 0 ]]
}
