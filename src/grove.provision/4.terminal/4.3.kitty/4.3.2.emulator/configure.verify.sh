#!/usr/bin/env bash
######################################################################
# .what = prove kitty is shaped as declared; READ-ONLY, repairs no claim
#
# .why
#   - presence is not correctness (.refs = gotcha.4-3-2-emulator.demo=kitty-loader-truth, m1)
#   - claims 2-5 are CONTENT-BLIND, so claim 1c diffs the live artifacts
#     against the checked-in source
#   - claim 4 stands apart from the upsert's own return code: it returns 0
#     silently when kitty is absent from PATH
#
# exit: 0 = every claim holds, incl. parse | 1 = a claim failed, and is named
#       3 = every checkable claim holds and the parse was NOT observed
######################################################################

# .what = print one ✋ failure (a headline plus optional detail lines), and count it
_kitty_verify_fail() {
  printf '   ✋ %s\n' "$1" >&2
  shift
  local line
  for line in "$@"; do
    [[ -n "$line" ]] && printf '      %s\n' "$line" >&2
  done
  failed=$(( failed + 1 ))
}

grove_provision_4_3_2_emulator_configure_verify() {
  local conf_dir="$HOME/.config/kitty"
  local conf="$conf_dir/kitty.conf"
  local bundle_dir="$GROVE_SRC/grove.provision/4.terminal/4.3.kitty/4.3.2.emulator"
  local failed=0 unverified=0

  # 1. the conf exists
  if [[ ! -f "$conf" ]]; then
    _kitty_verify_fail "no kitty.conf at $conf" \
      "⇒ configure.upsert did not take" \
      "fix: rhx grove.provision --what 4.3.2.emulator --mode apply"
    return 1
  fi
  echo "   • kitty.conf present"

  ####################################################################
  # 1b. the conf kitty READS is the one this bundle writes
  #
  # .why kitty prefers `KITTY_CONFIG_DIRECTORY`, and defaults to
  #   ~/.config/kitty — a shell rc, a .desktop Exec, or a systemd unit can
  #   export it, and claims 2-5 below then describe a conf that shapes no
  #   terminal
  ####################################################################
  local live_conf_dir="${KITTY_CONFIG_DIRECTORY:-$HOME/.config/kitty}"
  if [[ "$live_conf_dir" == "$conf_dir" ]]; then
    echo "   • kitty reads the conf this bundle writes ✔"
  else
    _kitty_verify_fail "KITTY_CONFIG_DIRECTORY points kitty at $live_conf_dir" \
      "⇒ this bundle writes $conf, so kitty reads a file this repo never wrote" \
      "fix: unset KITTY_CONFIG_DIRECTORY, or point it at $conf_dir"
  fi

  ####################################################################
  # 1c. the live conf, kittens, and theme match the checked-in source
  #
  # .why the deployed artifact is a plain `cp`, so a byte-diff is decisive —
  #   claims 2-5 check five PROPERTIES, and every one holds on a stale copy
  ####################################################################
  local pair dest mismatched=() named_absent=()
  for pair in kitty.conf:kitty.conf copy_notify.py:copy_notify.py \
    reboot_window.py:reboot_window.py desert.conf:themes/desert.conf; do
    dest="$conf_dir/${pair#*:}"
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

  ####################################################################
  # 1d. the kittens PARSE
  #
  # 🛑 claim 1c proves the BYTES match the checkout and says none of whether
  #   python accepts them
  #   - a kitten is loaded lazily, at the first keypress that maps to it
  #   - ⇒ a syntax error surfaces to a HUMAN mid-task, never to an apply
  #   - and it surfaces as a DEAD KEY, the same shape a wrong gate has, so
  #     the two are indistinguishable at the keyboard
  #
  # .why kitty's own interpreter — the box may carry no system python3, and
  #   this bundle has already put kitty's on disk
  ####################################################################
  local kitten unparsed=()
  for kitten in copy_notify.py reboot_window.py; do
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
    echo "   • both kittens parse ✔"
  fi

  ####################################################################
  # 2. the remote-control policy resolves to a DISABLED value, per kitty
  #
  # .why kitty's own loader reads, never a text-grep re-implementation
  #   - remote control is opt-in PER TERMINAL: the upsert writes `no`; a
  #     launch's own `-o` flags OUTRANK this file (rule.require.narrowest-terminal-grant)
  #   - kitty resolves the LAST assignment, and resolves `include` IN PLACE
  #   - a `== "yes"` deny has two holes: `true`/`y` pass verbatim, and
  #     `socket`/`socket-only` accept unconditionally — an ALLOWLIST of the
  #     three disabled spellings is the only safe read
  #   - .refs = gotcha.4-3-2-emulator.demo=kitty-loader-truth, m2-m6
  ####################################################################
  local rc_policy="" rc_source=""
  if command -v kitty >/dev/null 2>&1; then
    rc_policy="$(timeout -k 5 20 kitty +runpy "
from kitty.config import load_config
print(load_config('$conf').allow_remote_control)
" 2>/dev/null | tail -1 | tr -d '[:space:]')"
    [[ -n "$rc_policy" ]] && rc_source="kitty's own loader"
  fi
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
      "  as src/termwork.sh does" \
      "read why: rule.require.narrowest-terminal-grant"
  fi

  ####################################################################
  # 2b. the policy is STATED, not defaulted — asked apart from claim 2, since
  #   the loader above answers what kitty RESOLVES, declared or defaulted, so
  #   a release is free to change kitty's default with no diff here to show it
  ####################################################################
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

  ####################################################################
  # 2c. the DECLARED window size wins
  #
  # .why
  #   - `remember_window_size` defaults to yes and OVERRIDES initial_window_*
  #   - ⇒ size becomes cached state — the inversion this bundle exists to stop
  #     (rule.require.judge-declared-state-not-live-state)
  #
  # .why the LOADER, never a grep — claim 2's two reasons, verbatim
  #   - kitty resolves the LAST assignment, and resolves `include` IN PLACE
  #   - the value has several truthy spellings
  #
  # ⚠️ split from 2d on purpose, as 2 is from 2b
  #   - here = what kitty RESOLVES · 2d = whether we STATED it
  #   - ⇒ a defaulted pass leaves no diff to show a release that flipped it
  ####################################################################
  local rws=""
  if command -v kitty >/dev/null 2>&1; then
    rws="$(timeout -k 5 20 kitty +runpy "
from kitty.config import load_config
print(load_config('$conf').remember_window_size)
" 2>/dev/null | tail -1 | tr -d '[:space:]')"
  fi
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

  ####################################################################
  # 2d. the override is STATED, not defaulted — the same split as 2b
  ####################################################################
  if grep -Eq '^[[:space:]]*remember_window_size[[:space:]]+' "$conf"; then
    echo "   • the size-override policy is stated, not defaulted ✔"
  else
    _kitty_verify_fail "kitty.conf states no remember_window_size policy" \
      "⇒ kitty defaults it to yes, which overrides the two size lines below it — so a" \
      "  conf that declares a size and omits this one has declared no size at all" \
      "fix: rhx grove.provision --what 4.3.2.emulator --mode apply"
  fi

  ####################################################################
  # 3. every file kitty.conf NAMES actually exists, and the theme is included
  #
  # .why an absent kitten fails at KEYPRESS, never at startup, so ctrl+c does
  #   no copy, three layers from the file that is absent
  #   (rule.require.seam-claims-have-an-owner)
  ####################################################################
  if [[ ${#named_absent[@]} -eq 0 ]]; then
    echo "   • the theme and both kittens are on disk ✔"
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

  ####################################################################
  # 3b. notify-send, which copy_notify.py calls on its copy branch — checked
  #   here since provision.upsert owns the PACKAGE install, and the CALL has
  #   no owner: it fails mid-copy on a stripped box
  ####################################################################
  if command -v notify-send >/dev/null 2>&1; then
    echo "   • notify-send is reachable, so the copy toast can fire ✔"
  else
    _kitty_verify_fail "notify-send is absent" \
      "⇒ copy_notify.py shells out to it on every copy, so ctrl+c fails partway and" \
      "  reads as a broken clipboard" \
      "fix: rhx grove.provision --what 4.3.2.emulator --mode apply"
  fi
  ####################################################################
  # 4. kitty is the SELECTED default terminal, not merely a registered option
  #
  # 🛑 MANDATORY — settled by the human 2026-09-03: *"kitty is the
  #   default-terminal, that must be mandatorily enforced"*
  #   - ptyxis held this on the laptop, and ptyxis is not kitty
  #   - a ✋ here is CORRECT and stays red until the box is right
  #
  # 📜 this claim was DELETED on 2026-09-03 and restored the same minute
  #   - *"drop ptyxis"* was read as "drop the claim about ptyxis"
  #   - ⇒ the reader that CATCHES the defect was removed, and the defect kept
  #   - it cited `gotcha.a-check-that-cries-wolf-gets-silenced` as its reason,
  #     and that brief says the opposite: a check that reddens on a REAL defect
  #     is the one kind that must never be silenced
  ####################################################################
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

  ####################################################################
  # 5. does the conf actually PARSE, per kitty's own loader
  #
  # .why never `kitty --debug-config` — kitty rejects it as unknown, so a
  #   row built on it never settles. a `map` to an unknown action binds
  #   lazily, so this claim covers only what kitty reads at load
  #   (.refs = gotcha.4-3-2-emulator.demo=kitty-loader-truth, m7-m9)
  ####################################################################
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
    # ⚠️ judge the sentinel, never the exit code: `+runpy` exits 0 for a conf
    #   full of bad lines, since kitty CARRIES ON
    if [[ "$parse_rc" -ne 0 ]] || [[ "$parse_out" != *PARSE_READ_OK* ]]; then
      echo "   🌙 kitty's config loader did not answer; parse unproven"
      echo "      ⇒ it said: $(printf '%s' "$parse_out" | head -2 | tr '\n' ' ')"
      unverified=$(( unverified + 1 ))
    else
      # ⚠️ matches are CAPTURED, never `grep -q` — it exits on its first match,
      #   which SIGPIPEs the producer; under `pipefail` that reads 141 and
      #   opens the wrong branch (gotcha.pipefail-grep-q)
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

  # a disproven claim fails; an UNPROVEN one is stated above with a 🌙 and does not
  [[ "$failed" -eq 0 ]] || return 1
}
