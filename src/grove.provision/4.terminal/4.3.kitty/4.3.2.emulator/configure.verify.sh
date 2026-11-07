#!/usr/bin/env bash
######################################################################
# .what = prove kitty is shaped as declared; READ-ONLY, repairs no claim
# .why
#   - presence is not correctness, and kitty's own loader is the one truthful reader
#   - claim 4 stands apart from the upsert, which returns 0 when kitty is absent
# .refs = gotcha.4-3-2-emulator.demo=kitty-loader-truth — m1-m12, cited per claim
# exit: 0 = no claim disproven (an unproven one says 🌙) | 1 = a claim failed, and is named
######################################################################

grove_provision_4_3_2_emulator_configure_verify() {
  local conf_dir="$HOME/.config/kitty"
  local conf="$conf_dir/kitty.conf"
  local bundle_dir="$GROVE_SRC/grove.provision/4.terminal/4.3.kitty/4.3.2.emulator"
  local failed=0 unverified=0
  if [[ ! -f "$conf" ]]; then
    _kitty_verify_fail "no kitty.conf at $conf" \
      "⇒ configure.upsert did not take" \
      "fix: rhx grove.provision --what 4.3.2.emulator --mode apply"
    return 1
  fi
  echo "   • kitty.conf present"

  # 1b. the conf kitty READS is the one this bundle writes (m10)
  local live_conf_dir="${KITTY_CONFIG_DIRECTORY:-$HOME/.config/kitty}"
  if [[ "$live_conf_dir" == "$conf_dir" ]]; then
    echo "   • kitty reads the conf this bundle writes ✔"
  else
    _kitty_verify_fail "KITTY_CONFIG_DIRECTORY points kitty at $live_conf_dir" \
      "⇒ this bundle writes $conf, so kitty reads a file this repo never wrote" \
      "fix: unset KITTY_CONFIG_DIRECTORY, or point it at $conf_dir"
  fi

  # 1c. the live conf, kittens, and theme match the checkout, byte for byte (m10).
  #     ⚠️ the kitten set for 1d is DERIVED here, never re-typed — a second list drifts
  local pair dest mismatched=() named_absent=() kittens=()
  for pair in kitty.conf:kitty.conf copy_notify.py:copy_notify.py \
    reboot_window.py:reboot_window.py scroll_window.py:scroll_window.py \
    desert.conf:themes/desert.conf; do
    dest="$conf_dir/${pair#*:}"
    [[ "${pair%%:*}" == *.py ]] && kittens+=("${pair#*:}")
    if [[ ! -f "$dest" ]]; then named_absent+=("${pair#*:}")
    elif ! cmp -s "$bundle_dir/${pair%%:*}" "$dest"; then mismatched+=("${pair#*:}")
    fi
  done
  if [[ ${#mismatched[@]} -gt 0 ]]; then
    _kitty_verify_fail "${#mismatched[@]} file(s) do not match this checkout: ${mismatched[*]}" \
      "⇒ the deployed copy is STALE: any change added since is absent from the terminal in use" \
      "fix: rhx grove.provision --what 4.3.2.emulator --mode apply"
  elif [[ ${#named_absent[@]} -eq 0 ]]; then
    echo "   • kitty.conf, its kittens, and its theme match this checkout ✔"
  fi

  # 1d. the kittens PARSE, per kitty's own interpreter — a lazy load hides a break (m10)
  local kitten unparsed=()
  for kitten in "${kittens[@]}"; do
    [[ -f "$conf_dir/$kitten" ]] || continue
    kitty +runpy "
import sys
src = open('$conf_dir/$kitten').read()
try:
    compile(src, '$kitten', 'exec')
except SyntaxError as e:
    print('%s:%s %s' % ('$kitten', e.lineno, e.msg))
    sys.exit(1)
" >/dev/null 2>&1 || unparsed+=("$kitten")
  done
  if [[ ${#unparsed[@]} -gt 0 ]]; then
    _kitty_verify_fail "${#unparsed[@]} kitten(s) do not parse: ${unparsed[*]}" \
      "⇒ the key mapped to each is a SILENT no-op — kitty loads a kitten lazily," \
      "  so the break waits for a human mid-task and looks like a wrong gate" \
      "read why: kitty +runpy \"compile(open('$conf_dir/${unparsed[0]}').read(), 'k', 'exec')\""
  else
    echo "   • all ${#kittens[@]} kittens parse ✔"
  fi

  # 2. kitty's loader RESOLVES remote control to a disabled value — an allowlist (m2-m6)
  local rc_policy rc_source="kitty's own loader"
  rc_policy="$(_kitty_loader_get "$conf" 'o.allow_remote_control')"
  if [[ -z "$rc_policy" ]]; then
    echo "   🌙 kitty's config loader did not answer, so the effective"
    echo "      allow_remote_control is UNREAD on this box"
    echo "      fix: confirm kitty runs —  kitty +runpy 'print(1)'"
  else
    local rc_grant=""
    case "$rc_policy" in
      no|false|n)
        echo "   • remote-control policy ✔ ($rc_policy, per $rc_source)"
        ;;
      yes|true|y)
        rc_grant="the WIDEST grant: ALWAYS accepted, over the socket AND the tty — any process that reaches either drives every kitty window on this box ('true'/'y' are the same value)"
        ;;
      socket|socket-only)
        rc_grant="socket requests accepted UNCONDITIONALLY, no password — every hand-started kitty is drivable by any process that reaches the listen_on socket named below"
        ;;
      password)
        rc_grant="both channels open, gated on remote_control_password — still a BOX-WIDE grant where this design wants a per-terminal opt-in"
        ;;
      *)
        rc_grant="not one of kitty's three disabled spellings, so what it grants is UNREAD — and an unread grant is not a pass (rule.require.safe-by-default)"
        ;;
    esac
    [[ -n "$rc_grant" ]] && _kitty_verify_fail "kitty RESOLVES allow_remote_control to '$rc_policy'" \
      "⇒ $rc_grant" \
      "⚠️ the line at fault may sit in an included file — kitty resolves 'include' in" \
      "  place: grep -n 'allow_remote_control\\|include' $conf" \
      "fix: write 'allow_remote_control no' here; opt in PER TERMINAL at launch instead," \
      "  as src/grove.provision/2.shell/2.7.aliases/termwork.sh does" \
      "read why: rule.require.narrowest-terminal-grant"
  fi

  # 2b. the policy is STATED, not defaulted — a release may flip a default with no diff here
  if grep -Eq '^[[:space:]]*allow_remote_control[[:space:]]+' "$conf"; then
    echo "   • the policy is stated, not defaulted ✔"
  else
    _kitty_verify_fail "kitty.conf states no allow_remote_control policy" \
      "⇒ a release can change this box's security posture with no diff here to show it" \
      "  (rule.require.judge-declared-state-not-live-state)" \
      "fix: rhx grove.provision --what 4.3.2.emulator --mode apply"
  fi
  if grep -Eq '^[[:space:]]*listen_on[[:space:]]+' "$conf"; then
    echo "   • listen_on names a socket ✔"
  else
    _kitty_verify_fail "kitty.conf names no listen_on socket" \
      "⇒ a kitty a human starts by hand then opens no control socket, so 'kitten @'" \
      "  finds no window to talk to"
  fi

  # 2e. the render delays kitty READS — a delay felt as no change can mean either "no
  #     felt cost" or "never read", and only the loader parts the two
  local delays
  delays="$(_kitty_loader_get "$conf" "'%s %s' % (o.repaint_delay, o.input_delay)")"
  if [[ -z "$delays" ]]; then
    echo "   🌙 kitty's loader did not answer, so the render delays are UNREAD on this box"
  else
    echo "   • render delays read as repaint=${delays% *}ms input=${delays#* }ms ✔ (per kitty's own loader)"
    echo "     ⚠️ an open kitty keeps the delays it started with; a new one reads these"
  fi

  # 2c + 2d. the DECLARED window size wins, and that override is STATED (m11) — in _.sh
  _kitty_verify_window_size "$conf"

  # 2f. a BEL requests no focus, per the loader — the default does, and on wayland cosmic
  #     grants it, so two windows that beep steal focus from each other without end
  local wab
  wab="$(_kitty_loader_get "$conf" 'o.window_alert_on_bell')"
  if [[ -z "$wab" ]]; then
    echo "   🌙 kitty's loader did not answer, so whether a bell steals focus is UNREAD"
  else
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
  fi

  # 3. every file kitty.conf NAMES exists, and the theme is included (m10)
  if [[ ${#named_absent[@]} -eq 0 ]]; then
    echo "   • the theme and all ${#kittens[@]} kittens are on disk ✔"
  else
    _kitty_verify_fail "kitty.conf names ${#named_absent[@]} file(s) that are not readable" \
      "${named_absent[@]/#/• $conf_dir/}" \
      "fix: rhx grove.provision --what 4.3.2.emulator --mode apply"
  fi
  if grep -Eq '^[[:space:]]*include[[:space:]]+themes/desert\.conf' "$conf"; then
    echo "   • the desert theme is included ✔"
  else
    _kitty_verify_fail "kitty.conf does not include themes/desert.conf" \
      "⇒ a theme file on disk that no include line references never renders" \
      "fix: rhx grove.provision --what 4.3.2.emulator --mode apply"
  fi

  # 3b. notify-send, which copy_notify.py calls on each copy — a call with no other owner (m10)
  if command -v notify-send >/dev/null 2>&1; then
    echo "   • notify-send is reachable, so the copy toast can fire ✔"
  else
    _kitty_verify_fail "notify-send is absent" \
      "⇒ copy_notify.py shells out to it on every copy, so ctrl+c fails partway and" \
      "  reads as a broken clipboard" \
      "fix: rhx grove.provision --what 4.3.2.emulator --mode apply"
  fi
  # 4. kitty is the SELECTED default terminal. 🛑 MANDATORY — never drop this claim (m12)
  local selected; selected="$(update-alternatives --query x-terminal-emulator 2>/dev/null \
    | grep -E '^Value:' | awk '{print $2}')"
  case "$selected" in
    *kitty*) echo "   • default terminal is kitty ✔ ($selected)" ;;
    "")      _kitty_verify_fail "x-terminal-emulator has no selection at all" \
               "fix: rhx grove.provision --what 4.3.2.emulator --mode apply" ;;
    *)       _kitty_verify_fail "the default terminal is $selected, not kitty" \
               "⇒ ctrl+alt+t and every x-terminal-emulator caller open $selected" \
               "fix: rhx grove.provision --what 4.3.2.emulator --mode apply" \
               "⚠️ needs root, so run it from a seat with sudo" ;;
  esac

  # 5. the conf PARSES per kitty's loader (m7-m9) — judge the sentinel; CAPTURE, never `grep -q`
  if command -v kitty >/dev/null 2>&1; then
    local parse_out parse_rc=0
    parse_out="$(timeout -k 5 20 kitty +runpy "
from kitty.config import load_config
bad = []
load_config('$conf', accumulate_bad_lines=bad)
for b in bad:
    print('BADLINE line %s: %s' % (b.number, b.exception))
print('PARSE_READ_OK')
" 2>&1)" || parse_rc=$?
    if [[ "$parse_rc" -ne 0 ]] || [[ "$parse_out" != *PARSE_READ_OK* ]]; then
      echo "   🌙 kitty's config loader did not answer; parse unproven"
      echo "      ⇒ it said: $(printf '%s' "$parse_out" | head -2 | tr '\n' ' ')"
      unverified=$(( unverified + 1 ))
    else
      local complaints
      complaints="$(printf '%s\n' "$parse_out" \
        | grep -E '^BADLINE |unknown config key' || true)"
      if [[ -n "$complaints" ]]; then
        _kitty_verify_fail "kitty.conf parses WITH complaints:" \
          "$(printf '%s\n' "$complaints" | head -5 | sed 's/^/  /')" \
          "⇒ kitty carries on past each of these, running with the directive absent" \
          "  rather than with an error" \
          "fix: rhx grove.provision --what 4.3.2.emulator --mode apply"
      else
        echo "   • kitty.conf parses clean ✔ (per kitty's own loader)"
      fi
    fi
  else
    echo "   🌙 kitty is absent from PATH, so whether kitty.conf PARSES cannot"
    echo "      be observed. the claims above did hold."
    unverified=$(( unverified + 1 ))
  fi

  [[ "$failed" -eq 0 ]] || return 1
}
