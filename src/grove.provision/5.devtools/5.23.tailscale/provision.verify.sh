#!/usr/bin/env bash
######################################################################
# .what = prove tailscale is present, from its signed source, with its daemon
#         enabled and active
#
# .the JOIN is not checked here — that is the configure phase's claim
#
# .cloud@* — the provisioner installed it, from ITS apt source
#   - ⇒ the client and the daemon are checked; this repo's source path is not,
#     since a provisioner's own source is no defect
#   - an absent client is the provisioner's step, failed, and is named so
#
# guarantee:
#   - READ-ONLY
######################################################################

grove_provision_5_23_tailscale_provision_verify() {
  local keydst listdst failed=0 cloud=0
  keydst="$(grove_provision_5_23_tailscale_keydst)"
  listdst="$(grove_provision_5_23_tailscale_listdst)"
  [[ "${GROVE_ENV_SERVER:-}" == cloud@* ]] && cloud=1

  # each fact is read once, then reported; a ✋ marks the run failed, never stops it,
  #   so one verify names every absent fact at once
  local has_client=0 has_source=0 has_unit=0
  command -v tailscale >/dev/null 2>&1 && has_client=1
  [[ $cloud -eq 0 ]] && grove_provision_5_23_tailscale_source_ok && has_source=1
  systemctl is-enabled --quiet tailscaled 2>/dev/null \
    && systemctl is-active --quiet tailscaled 2>/dev/null && has_unit=1

  # the client
  [[ $has_client -eq 1 ]] && echo "   • tailscale present ($(tailscale version 2>/dev/null | head -1)) ✔"
  if [[ $has_client -eq 0 ]]; then
    echo "   ✋ ConstraintError: tailscale is not on PATH" >&2
    echo "      ⇒ the one package brings the client and tailscaled, so the daemon is not read apart" >&2
    failed=1
  fi

  # the signed source — this repo's, on a laptop alone
  [[ $cloud -eq 0 && $has_source -eq 1 ]] && echo "   • apt source declared, signed by the pinned key ✔"
  if [[ $cloud -eq 0 && $has_source -eq 0 ]]; then
    echo "   ✋ ConstraintError: tailscale's signed apt source is not declared as this bundle writes it" >&2
    echo "      want: $(grove_provision_5_23_tailscale_list_line 2>/dev/null) in ${listdst}" >&2
    echo "      and:  ${keydst} with primary $(grove_provision_5_23_tailscale_fpr)" >&2
    echo "      ⇒ a commented-out line, a stale codename, or a swapped key all read here:" >&2
    echo "        without the exact source, \`apt upgrade\` never brings tailscale current" >&2
    failed=1
  fi

  # the daemon — read only where the client is; with no client, its header says both
  [[ $has_unit -eq 1 ]] && echo "   • tailscaled enabled and active ✔"
  if [[ $has_unit -eq 0 && $has_client -eq 1 ]]; then
    echo "   ✋ ConstraintError: tailscaled is not both enabled and active" >&2
    echo "      read why: systemctl status tailscaled" >&2
    failed=1
  fi

  # on a grove, the fix is the provisioner's — a rerun here installs naught
  if [[ $failed -eq 1 && $cloud -eq 1 ]]; then
    echo "      ⇒ this grove's provisioner did not install or start tailscale" >&2
    grove_provision_5_23_tailscale_provisioner_say >&2
    return 1
  fi
  if [[ $failed -eq 1 ]]; then
    echo "      fix: $(grove_provision_5_23_tailscale_rerun)" >&2
    return 1
  fi
  return 0
}
