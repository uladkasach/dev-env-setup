#!/usr/bin/env bash
######################################################################
# .what = prove earlyoom is installed AND that its service is ACTIVE
#
# ⚠️ .why the service state is its own claim
#         the package can be installed while the unit is disabled, masked, or
#         failed. in that state a presence check passes and no daemon watches
#         memory — the box reports as armed and locks up under the first real
#         pressure. this is the same "the bytes arrived" vs "the capacity exists"
#         line `1.6.2.monitor.provision.verify` draws about its timer.
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
######################################################################

grove_provision_1_6_3_earlyoom_provision_verify() {
  local failed=0

  ####################################################################
  # 1. the binary is on PATH
  ####################################################################
  local bin
  bin="$(bundle.bin.of earlyoom)"

  if [[ -n "$bin" ]]; then
    echo "   • earlyoom is on PATH ✔"
  else
    echo "   ✋ earlyoom is absent from PATH" >&2
    echo "      fix: rhx grove.provision --what 1.6.3.earlyoom --mode apply" >&2
    failed=1
  fi

  ####################################################################
  # 2. THE claim — the service is live NOW and survives a reboot
  #
  # see the header for why an installed package leaves this unproven
  #
  # ⚠️ .why BOTH `is-active` and `is-enabled`
  #      they answer different questions and neither implies the other:
  #        is-active  → is it live in THIS boot
  #        is-enabled → will it come back after a REBOOT
  #      a `systemctl start earlyoom` with no `enable` is active and disabled: it
  #      passes an is-active check today and is gone tomorrow. for an oom killer
  #      that is the whole point — the pressure it exists to survive is exactly
  #      what makes a human reboot
  ####################################################################
  local state_active state_enabled
  state_active="$(systemctl is-active earlyoom 2>/dev/null)"
  state_enabled="$(systemctl is-enabled earlyoom 2>/dev/null)"

  if [[ "$state_active" == "active" ]]; then
    echo "   • earlyoom.service is active ✔"
  else
    echo "   ✋ earlyoom.service is '${state_active:-absent}', not active" >&2
    echo "      ⇒ no daemon watches memory, so the box locks up under the first" >&2
    echo "        real pressure while it reports as armed" >&2
    echo "      read why: systemctl status earlyoom" >&2
    echo "      fix: rhx grove.provision --what 1.6.3.earlyoom --mode apply" >&2
    failed=1
  fi

  if [[ "$state_enabled" == "enabled" ]]; then
    echo "   • earlyoom.service is enabled — it returns after a reboot ✔"
  else
    echo "   ✋ earlyoom.service is '${state_enabled:-absent}', not enabled" >&2
    echo "      ⇒ it may be active THIS boot and gone the next, so the box loses" >&2
    echo "        its oom guard at exactly the reboot that memory pressure caused" >&2
    echo "      fix: rhx grove.provision --what 1.6.3.earlyoom --mode apply" >&2
    failed=1
  fi

  return $failed
}
