#!/usr/bin/env bash
######################################################################
# .what = prove both keys are declared on disk AND live in the kernel
#
# .why BOTH, and why they are separate claims
#   - they can disagree in either direction, and each is a real defect with its own fix:
#
#     declared, not live   `sysctl -p` failed, usually on an unrelated bad line
#     live, not declared   somebody set it by hand with `sysctl -w`
#
#   - a file-only check misses the first, and a live-only check misses the second
#   - ⇒ both are asserted, since this is the rare bundle where both are cheaply observable
#
# guarantee:
#   - READ-ONLY. it greps one file and reads two values from /proc via sysctl -n.
#     it repairs no state
#
# exit:
#   0 = both keys are declared and live
#   1 = a key is absent from the file, or the live kernel disagrees with it
######################################################################

grove_provision_1_4_sysctl_configure_verify() {
  local conf="/etc/sysctl.conf"
  local failed=0

  ####################################################################
  # .why one operation for both keys
  #   - a second copy of the same three-step check is a second place to drift
  ####################################################################
  __sysctl_claim() {
    local key="$1" want="$2" live=""

    if ! grep -q "^${key}=${want}\$" "$conf"; then
      echo "   ✋ $conf does not declare ${key}=${want}" >&2
      echo "      ⇒ so it reverts to the stock value at the next boot" >&2
      echo "      fix: rhx grove.provision --what 1.4.sysctl --mode apply" >&2
      return 1
    fi

    live="$(sysctl -n "$key" 2>/dev/null)"
    if [[ -z "$live" ]]; then
      echo "   ✋ the kernel reports no value for $key" >&2
      echo "      ⇒ the key name itself is wrong, or this kernel lacks it" >&2
      return 1
    fi

    if [[ "$live" != "$want" ]]; then
      echo "   ✋ $key is declared $want but the kernel runs $live" >&2
      echo "      ⇒ the file landed and 'sysctl -p' did not take, so the box behaves" >&2
      echo "        as if unconfigured — and a file-only check would have passed" >&2
      echo "      read why: sudo sysctl -p    # it names the line at fault" >&2
      return 1
    fi

    echo "   • $key = $want, declared and live ✔"
  }

  __sysctl_claim fs.inotify.max_user_watches 524288 || failed=$(( failed + 1 ))
  __sysctl_claim vm.swappiness 10                   || failed=$(( failed + 1 ))

  unset -f __sysctl_claim

  [[ "$failed" -eq 0 ]] || return 1
}
