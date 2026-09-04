#!/usr/bin/env bash
######################################################################
# .what = prove that a terminfo LOOKUP of `xterm-kitty` succeeds on this machine
#
# .why
#   - the upsert's exit code says its commands returned 0, never that the entry is findable
#   - a package can install while the entry lands where ncurses does not read
#   - 📜 2026-07-29: its absence cost three complaints that read as three bugs
#   - 📜 "tmux not usable", "core utils broken", "backspaces render as spaces"
#
# .`infocmp`, and NOT `dpkg -l kitty-terminfo`
#   - the DECLARATION is that a program which asks for xterm-kitty gets an answer
#   - ⚠️ `tput -T xterm-kitty` would not do either, since it answers from a fallback
#   - so tput can exit 0 on a box that holds no entry at all
#
# guarantee
#   - READ-ONLY: it queries the terminfo db and repairs no state
######################################################################

grove_provision_4_3_1_terminfo_provision_verify() {
  if ! command -v infocmp &>/dev/null; then
    echo "   ✋ infocmp is absent, so this claim cannot be checked" >&2
    echo "      ⇒ infocmp ships in ncurses-bin, which this bundle's upsert owns" >&2
    echo "      fix: rhx grove.provision --what 4.3.1.terminfo --mode apply" >&2
    return 1
  fi

  if ! infocmp xterm-kitty &>/dev/null; then
    echo "   ✋ a lookup of xterm-kitty FAILS on this machine" >&2
    echo "      ⇒ a human who ssh's in from kitty will find tmux refuses to" >&2
    echo "        start, ncurses tools garbled, and backspace drawn as a space" >&2
    echo "      fix: rhx grove.provision --what 4.3.1.terminfo --mode apply" >&2
    return 1
  fi

  ####################################################################
  # WHERE the lookup lands is still worth a line
  #   - the claim is that EVERY account on this box finds the entry
  #   - a per-user `~/.terminfo` copy satisfies it for THIS user alone
  #   - a box may carry one from an earlier hand-fix, so a reader is told
  ####################################################################
  local from; from="$(infocmp -1 xterm-kitty 2>/dev/null | grep -o '/[^ ]*terminfo[^ ]*' | head -1)"
  case "$from" in
    ##################################################################
    # ⚠️ every line of this arm is on STDOUT, the note included
    #   - the runtime carries stderr on a SEPARATE pipe, with no relative order
    #   - so a note on stderr could print inside another bundle's block
    #   - that unordered delivery is right for a ✋, which SHOULD draw the eye
    #   - this arm raises no failure, so it wants neither property
    ##################################################################
    "$HOME"/*) echo "   • xterm-kitty found ✔ (per-user, at $from)"
               echo "     note: this serves $USER only; another account here is unserved."
               echo "     ⇒ a hand-compiled leftover. the package is system-wide:"
               echo "       sudo apt-get install -y kitty-terminfo" ;;
    "")        echo "   • xterm-kitty found ✔" ;;
    *)         echo "   • xterm-kitty found ✔ (system-wide, at $from)" ;;
  esac
}
