#!/usr/bin/env bash
######################################################################
# .what = prove every path to a suspend is declared shut, in BOTH files
#
# .why it asserts the keys and not the files
#   - both files EXIST on every systemd box, with every key shipped as a comment
#   - ⇒ `[[ -f logind.conf ]]` is true on a box that suspends the moment its lid closes
#   - a file test carries no information here at all
#
# .why the effective state IS partly checkable, unlike 1.1.keybinds
#   - `loginctl show-session` reports logind's LIVE values, not the file's text
#   - ⇒ it separates "declared" from "in effect"
#   - the difference between them is exactly the reboot the upsert says is owed
#   - so this reports both and does not fail on a difference
#   - a declaration that awaits a reboot is correct work, not a defect
#
# guarantee:
#   - READ-ONLY. it reads two conf files and queries loginctl; repairs no state
#
# exit:
#   0 = every key is declared. whether it is LIVE yet is reported, never failed
#   1 = a key is absent from a conf, so a trigger remains live after a reboot too
######################################################################

grove_provision_1_2_power_configure_verify() {
  local logind_conf="/etc/systemd/logind.conf"
  local sleep_conf="/etc/systemd/sleep.conf"
  local failed=0 key

  ####################################################################
  # 1. logind — every trigger declared ignored
  ####################################################################
  for key in HandlePowerKey HandleSuspendKey HandleHibernateKey \
             HandleLidSwitch HandleLidSwitchExternalPower HandleLidSwitchDocked \
             IdleAction; do
    if grep -q "^${key}=ignore" "$logind_conf" 2>/dev/null; then continue; fi
    echo "   ✋ logind.conf does not declare ${key}=ignore" >&2
    failed=$(( failed + 1 ))
  done
  if [[ "$failed" -eq 0 ]]; then
    echo "   • logind declares every trigger ignored ✔"
  else
    echo "      ⇒ each key above is a live path to a suspend or a lock. the file" >&2
    echo "        SHIPS with them present as comments, so its existence proves none" >&2
    echo "      fix: rhx grove.provision --what 1.2.power --mode apply" >&2
  fi

  ####################################################################
  # 2. sleep — the act itself declared disallowed
  ####################################################################
  local sleepfailed=0
  for key in AllowSuspend AllowHibernation AllowSuspendThenHibernate AllowHybridSleep; do
    if grep -q "^${key}=no" "$sleep_conf" 2>/dev/null; then continue; fi
    echo "   ✋ sleep.conf does not declare ${key}=no" >&2
    sleepfailed=$(( sleepfailed + 1 ))
  done
  if [[ "$sleepfailed" -eq 0 ]]; then
    echo "   • sleep declares every mode disallowed ✔"
  else
    echo "      ⇒ logind alone leaves 'systemctl suspend' and every desktop menu" >&2
    echo "        item live; this file is what refuses the act itself" >&2
    failed=$(( failed + sleepfailed ))
  fi

  ####################################################################
  # 3. and the [Sleep] header, without which the keys above are ignored
  ####################################################################
  if grep -q '^\[Sleep\]' "$sleep_conf" 2>/dev/null; then
    echo "   • sleep.conf declares its [Sleep] section ✔"
  else
    echo "   ✋ sleep.conf has no [Sleep] section" >&2
    echo "      ⇒ keys outside a section are ignored SILENTLY, so the four Allow" >&2
    echo "        lines read correct in a cat and apply to no mode at all" >&2
    failed=$(( failed + 1 ))
  fi

  ####################################################################
  # 4. is it LIVE yet? — reported, never failed
  #
  # .why not a failure
  #   - logind reads its config at start, so a declaration that awaits the next login is correct
  #   - a failure here would fail every run until a reboot
  #   - ⇒ that teaches a reader to ignore this bundle's output
  ####################################################################
  local live; live="$(loginctl show-session 2>/dev/null | grep -E '^IdleAction=' | head -1)"
  if [[ "$live" == "IdleAction=ignore" ]]; then
    echo "   • and logind is LIVE with it ✔ ($live)"
  elif [[ -n "$live" ]]; then
    echo "   🌙 declared, not yet live — logind still runs with '$live'"
    echo "      it reads its config at start, so this takes on the next login"
    echo "      to apply now: machine.logout"
  else
    echo "   🌙 unverified — loginctl reported no session, so whether logind is"
    echo "      LIVE with the declaration above cannot be observed from this run"
  fi

  [[ "$failed" -eq 0 ]] || return 1
}
