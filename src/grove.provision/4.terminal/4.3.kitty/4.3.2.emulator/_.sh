#!/usr/bin/env bash
######################################################################
# .what = the kitty terminal itself — the pinned build, and its config
#
# .why it applies to EVERY machine, headless included, with NO early return
#   - a box HOLDS kitty without a display; only the window needs one
#   - a grove needs `kitten`, which every termwork skill drives
# .refs = gotcha.4-3-2-emulator.demo=kitty-loader-truth, m13
#
# usage:
#   rhx grove.provision --what 4.3.2.emulator --mode apply
######################################################################

# .what = print one ✋ failure (a headline plus optional detail lines), and count it
#   in the CALLER's `failed` (configure.verify), which bash scopes dynamically
_kitty_verify_fail() {
  printf '   ✋ %s\n' "$1" >&2
  shift
  local line
  for line in "$@"; do
    [[ -n "$line" ]] && printf '      %s\n' "$line" >&2
  done
  failed=$(( failed + 1 ))
}

# .what = print what kitty's own loader resolves for one python expr over `o`, the loaded conf
# .why kitty's loader is the one truthful reader (m2-m6); empty output = kitty absent or mute
_kitty_loader_get() {
  local conf="$1" expr="$2"
  command -v kitty >/dev/null 2>&1 || return 0
  timeout -k 5 20 kitty +runpy "
from kitty.config import load_config
o = load_config('$conf')
print($expr)
" </dev/null 2>/dev/null | tail -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# .what = claim 2f of configure.verify: a BEL requests no focus, per kitty's loader
# .why the default does, and on wayland cosmic grants it, so two windows that beep
#   steal focus from each other without end
_kitty_verify_bell() {
  local conf="$1" wab
  wab="$(_kitty_loader_get "$conf" 'o.window_alert_on_bell')"
  if [[ -z "$wab" ]]; then
    echo "   🌙 kitty's loader did not answer, so whether a bell steals focus is UNREAD"
    return 0
  fi
  case "$wab" in
    no|false|n|False)
      echo "   • a bell marks the tab and steals no focus ✔ ($wab, per kitty's own loader)"
      ;;
    *)
      _kitty_verify_fail "kitty RESOLVES window_alert_on_bell to '$wab'" \
        "⇒ every BEL becomes an xdg-activation request, and cosmic grants it as focus" \
        "⇒ two windows that each beep thrash focus back and forth and burn cpu" \
        "fix: rhx grove.provision --what 4.3.2.emulator --mode apply" \
        "⚠️ an open kitty keeps the value it started with; a new one reads this"
      ;;
  esac
}

# .what = claim 2g of configure.verify: a program may write the clipboard, per the loader
# .why
#   - tmux copy-mode (and nvim in a duct) copies by an osc 52 write to kitty, the last hop
#   - without `write-clipboard` kitty drops it, so a paste yields the OLD clipboard, silently
#   - the tmux half of that hop is 2.8.tmux's `clipboard` feature check
_kitty_verify_clipboard() {
  local conf="$1" ccw=""
  if command -v kitty >/dev/null 2>&1; then
    ccw="$(timeout -k 5 20 kitty +runpy "
from kitty.config import load_config
print('write-clipboard' in load_config('$conf').clipboard_control)
" </dev/null 2>/dev/null | tail -1 | tr -d '[:space:]')"
  fi
  case "$ccw" in
    True)
      echo "   • a program may write the clipboard ✔ (write-clipboard, per kitty's own loader)"
      ;;
    False)
      _kitty_verify_fail "kitty's clipboard_control lacks write-clipboard" \
        "⇒ an osc 52 write is dropped, so a tmux copy-mode copy (super+v, ctrl+c) and an" \
        "  nvim yank in a duct never reach the desktop clipboard — silently" \
        "fix: rhx grove.provision --what 4.3.2.emulator --mode apply" \
        "⚠️ an open kitty keeps the value it started with; a new one reads this"
      ;;
    *)
      echo "   🌙 kitty's loader did not answer, so whether a program may write the clipboard is UNREAD"
      ;;
  esac
}

# .what = claims 2c + 2d of configure.verify: the DECLARED window size wins over
#   `remember_window_size`, per kitty's loader, and that override is STATED (m11)
_kitty_verify_window_size() {
  local conf="$1" rws
  rws="$(_kitty_loader_get "$conf" 'o.remember_window_size')"
  if [[ -z "$rws" ]]; then
    echo "   🌙 kitty's loader did not answer, so whether the DECLARED window"
    echo "      size wins is UNREAD on this box"
  else
    case "$rws" in
      no|false|n|False)
        echo "   • the declared window size wins ✔ ($rws, per kitty's own loader)"
        ;;
      *)
        _kitty_verify_fail "kitty RESOLVES remember_window_size to '$rws'" \
          "⇒ it overrides initial_window_*, so every new window inherits the geometry of" \
          "  the last one CLOSED, and the size declared here is ignored" \
          "⇒ measured 2026-09-03: a 6-tree fleet, zero windows at the declared size, worst" \
          "  27 cols — narrow enough to wrap claude's modal chrome, so a stall detector" \
          "  keyed on it read a live modal as an idle box" \
          "⚠️ the line at fault may sit in an included file — kitty resolves 'include' in" \
          "  place: grep -n 'remember_window_size\\|include' $conf" \
          "fix: rhx grove.provision --what 4.3.2.emulator --mode apply" \
          "⚠️ an open window keeps its size; this reaches the NEXT one opened"
        ;;
    esac
  fi

  if grep -Eq '^[[:space:]]*remember_window_size[[:space:]]+' "$conf"; then
    echo "   • the size-override policy is stated, not defaulted ✔"
  else
    _kitty_verify_fail "kitty.conf states no remember_window_size policy" \
      "⇒ kitty defaults it to yes, which overrides the two size lines below it — so a" \
      "  conf that declares a size and omits this one has declared no size at all" \
      "fix: rhx grove.provision --what 4.3.2.emulator --mode apply"
  fi
}

grove_provision_4_3_2_emulator() {
  bundle.upgrade 4.3.2.emulator.provision.upsert
  bundle.upgrade 4.3.2.emulator.provision.verify
  bundle.upgrade 4.3.2.emulator.configure.upsert
  bundle.upgrade 4.3.2.emulator.configure.verify
}
