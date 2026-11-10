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

# .what = one python expression over `o`, the options kitty's own loader resolves from
#   the conf at $1; prints the answer, or naught when kitty is absent or does not answer
_kitty_loader_read() {
  command -v kitty >/dev/null 2>&1 || return 0
  timeout -k 5 20 kitty +runpy "
from kitty.config import load_config
o = load_config('$1')
print($2)
" 2>/dev/null | tail -1
}

# .what = claims 2c + 2d of configure.verify: the DECLARED window size wins over
#   `remember_window_size`, per kitty's loader, and that override is STATED (m11)
_kitty_verify_window_size() {
  local conf="$1" rws
  rws="$(_kitty_loader_read "$conf" o.remember_window_size | tr -d '[:space:]')"
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
