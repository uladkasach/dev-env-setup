#!/usr/bin/env bash
######################################################################
# .what = prove swap is ACTIVE, and that it re-arms at boot
#
# .why the two claims are separate
#   - `swapon --show` proves swap is live NOW, and `/etc/fstab` proves it comes back
#   - active-but-unrecorded works today and the box wakes with no swap
#   - ⇒ the oom kills start weeks later with no change to blame
#   - recorded-but-inactive means the last `swapon` failed, which a file check calls a pass
#
# .why it does NOT assert /swapfile specifically
#   - a box may get its swap from an image `/swap-hibinit`, from zram, or from a partition
#   - the CLAIM is "this box has swap that survives a reboot", not "it has my file"
#   - ⇒ a check for the path would fail on every hibernatable grove
#   - that is the very box the upsert defers to
#
# ⚠️ absent swap on a DEFERRED box is a 🌙, never a ✋
#   - the upsert returns 0 without a write when `/sys/power/resume_offset` is nonzero
#   - the image registered the swap target, and a second swapfile would break hibernate
#   - ⇒ that is a deliberate defer, not owed work
#   - 📜 grove-1 2026-07-30: a ✋ here made `1.system` exit 1 on EVERY run, forever
#   - the fix it named was the very command that had just declined
#   - ⇒ an error whose fix the box cannot execute is a dead end in a fix's costume
#   - and a ✋ that can never clear teaches a reader to skim past every ✋ this section prints
#
# guarantee:
#   - READ-ONLY. it reads swapon output, /etc/fstab, and /sys/power. repairs no state
#
# exit:
#   0 = swap is active and will re-arm, OR this box defers to an image that owns it
#   1 = there is no active swap, or active swap that no boot will restore
######################################################################

grove_provision_1_5_swap_configure_verify() {
  local failed=0

  ####################################################################
  # 0. who OWNS the swap on this box?
  #
  # .read first, because it changes what every answer below MEANS
  #   - a nonzero resume offset says the image registered its own hibernation target
  #   - ⇒ the upsert deferred, and this bundle judges a box it does not write to
  ####################################################################
  local resume_offset
  resume_offset="$(cat /sys/power/resume_offset 2>/dev/null || echo 0)"
  local deferred="false"
  [[ -n "$resume_offset" && "$resume_offset" != "0" ]] && deferred="true"

  ####################################################################
  # 1. is there ANY active swap?
  ####################################################################
  local active; active="$(swapon --show=NAME --noheadings 2>/dev/null)"
  if [[ -z "$active" ]]; then
    ##################################################################
    # .on a DEFERRED box this is expected, not owed
    #   - 📜 right after a resume an aws hibernatable box shows no active swap at all
    #   - the image is what arms it back
    #   - ⇒ there is no work this bundle could do, and no fix it could name
    ##################################################################
    if [[ "$deferred" == "true" ]]; then
      echo "   🌙 no active swap, and that is not this bundle's to repair"
      echo "      this box registers a hibernation resume target (offset"
      echo "      $resume_offset), so the image owns its swap and the upsert"
      echo "      deferred. a box also shows no active swap right after a resume"
      echo "      to check by hand: swapon --show, and cat /sys/power/resume"
      return 0
    fi

    echo "   ✋ this box has NO active swap" >&2
    echo "      ⇒ with no swap the kernel oom-kills a RUNNING process rather than" >&2
    echo "        page out an idle one, which is what this bundle exists to prevent" >&2
    echo "      fix: rhx grove.provision --what 1.5.swap --mode apply" >&2
    return 1
  fi
  echo "   • swap is active ✔ ($(echo "$active" | tr '\n' ' '))"

  ####################################################################
  # 2. will it come back after a reboot?
  #
  # .two legitimate answers
  #   - fstab names it
  #   - or the image registered it as a hibernation target and arms it itself
  ####################################################################
  local in_fstab="false" one
  while read -r one; do
    [[ -n "$one" ]] || continue
    grep -q "^${one} " /etc/fstab 2>/dev/null && { in_fstab="true"; break; }
  done <<< "$active"

  if [[ "$in_fstab" == "true" ]]; then
    echo "   • and /etc/fstab records it, so it re-arms at boot ✔"
  elif [[ "$deferred" == "true" ]]; then
    echo "   • not in fstab, and that is CORRECT here — this box registers a"
    echo "     hibernation resume target (offset $resume_offset), so the image arms"
    echo "     its own swap. this bundle deferred to it on purpose"
  else
    echo "   ✋ swap is active but NO boot will restore it" >&2
    echo "      ⇒ /etc/fstab names none of the active swap, and this box registers" >&2
    echo "        no hibernation target that would arm it instead" >&2
    echo "      ⇒ this is the worst shape: it works today, and the box wakes with" >&2
    echo "        no swap — so the oom kills start weeks later with no change to blame" >&2
    echo "      fix: rhx grove.provision --what 1.5.swap --mode apply" >&2
    failed=$(( failed + 1 ))
  fi

  [[ "$failed" -eq 0 ]] || return 1
}
