#!/usr/bin/env bash
######################################################################
# .what = prove the firewall is declared as the repo writes it, armed at boot,
#         and loaded
#
# .why the verdict rests on the DECLARATION
#   - the ruleset and the unit are byte-compared to the repo copy, and the unit
#     must be enabled: that is what holds after a reboot
#     (`rule.require.judge-declared-state-not-live-state`)
#   - the live table itself needs root to read, and this phase is read-only and
#     unprivileged — so the unit's state is the one live read it takes
#
# .why `failed` and `inactive` are ✋ all the same
#   - `failed` means the declaration does NOT load on this kernel — a defect in
#     the declaration, which a reboot repeats, never a transient
#   - `inactive` means someone stopped it: the box is open now, on whatever
#     network it sits on, and a laptop is exactly the box that roams
#
# guarantee:
#   - READ-ONLY. it compares two files and asks systemd two questions
######################################################################

grove_provision_1_12_firewall_configure_verify() {
  grove_provision_1_12_firewall_applies || return 0

  local src_rules src_unit dst_rules dst_unit unit failed=0
  src_rules="$(grove_provision_1_12_firewall_dir)/firewall.nft"
  src_unit="$(grove_provision_1_12_firewall_dir)/grove-firewall.service"
  dst_rules="$(grove_provision_1_12_firewall_ruleset_at)"
  dst_unit="$(grove_provision_1_12_firewall_unit_at)"
  unit="$(grove_provision_1_12_firewall_unit)"

  # the two declared files — each one read, then reported
  local pair src dst
  for pair in "$src_rules|$dst_rules" "$src_unit|$dst_unit"; do
    src="${pair%%|*}"; dst="${pair##*|}"
    if cmp -s "$src" "$dst"; then
      echo "   • $dst matches the repo ✔"
      continue
    fi
    if [[ -e "$dst" ]]; then
      echo "   ✋ ConstraintError: $dst differs from the repo copy" >&2
      echo "      ⇒ an edit on the box, or an apply from an older checkout" >&2
      echo "      read the drift: diff $src $dst" >&2
    else
      echo "   ✋ ConstraintError: $dst is absent — no firewall is declared" >&2
    fi
    failed=1
  done

  # armed at boot — the claim that survives a reboot
  local enabled active
  enabled="$(grove_provision_1_12_firewall_unit_state is-enabled)"
  active="$(grove_provision_1_12_firewall_unit_state is-active)"
  if [[ "$enabled" == enabled ]]; then
    echo "   • $unit enabled — loads before any network, at every boot ✔"
  else
    echo "   ✋ ConstraintError: $unit is-enabled=$enabled — the box boots with no firewall" >&2
    failed=1
  fi

  # loaded this boot
  case "$active" in
    active)
      echo "   • $unit active — inbound dropped this boot ✔" ;;
    failed)
      echo "   ✋ ConstraintError: $unit failed — the declared ruleset did not load" >&2
      echo "      ⇒ a defect in the declaration; the next boot fails the same way" >&2
      echo "      read why: journalctl -u $unit -n 30" >&2
      failed=1 ;;
    *)
      echo "   ✋ ConstraintError: $unit is-active=$active — inbound is open this boot" >&2
      failed=1 ;;
  esac

  if [[ $failed -eq 1 ]]; then
    echo "      fix: $(grove_provision_1_12_firewall_rerun)" >&2
    echo "      read the whole picture: rhx network.firewall.get" >&2
    return 1
  fi
}
