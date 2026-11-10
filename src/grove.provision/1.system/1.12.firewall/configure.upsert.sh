#!/usr/bin/env bash
######################################################################
# .what = declare the firewall (ruleset + unit), arm it at boot, and load it now
#
# .the four facts, each read before any root is asked for
#   - the ruleset at /etc/grove/firewall.nft matches the repo copy, byte for byte
#   - the unit at /etc/systemd/system/grove-firewall.service matches likewise
#   - the unit is enabled — so the drop loads before any link, at every boot
#   - the unit is active — so the drop holds this boot too
#   - ⇒ all four hold → no work, and no root asked for
#
# .why the repo copy is CHECKED before it is written
#   - `nft -c` parses it against this kernel with no rule applied
#   - ⇒ a ruleset this kernel rejects never lands, so the box keeps whatever
#     firewall it had rather than gain a unit that fails at every boot
#
# .why reload, never restart
#   - restart runs ExecStop, which deletes the table: an open gap until start
#   - reload runs the file, which replaces the table in ONE transaction
#
# guarantee:
#   - idempotent: each file is written only where it differs
#   - declines on every tier but `local@unix` (`_.sh`), and where this seat
#     holds no root (`bundle.root.owns`)
######################################################################

grove_provision_1_12_firewall_configure_upsert() {
  grove_provision_1_12_firewall_applies || return 0

  local src_rules src_unit dst_rules dst_unit unit
  src_rules="$(grove_provision_1_12_firewall_dir)/firewall.nft"
  src_unit="$(grove_provision_1_12_firewall_dir)/grove-firewall.service"
  dst_rules="$(grove_provision_1_12_firewall_ruleset_at)"
  dst_unit="$(grove_provision_1_12_firewall_unit_at)"
  unit="$(grove_provision_1_12_firewall_unit)"

  ####################################################################
  # 0. what already holds — every read here is free and needs no root
  ####################################################################
  local rules_ok=0 unit_ok=0 enabled active
  cmp -s "$src_rules" "$dst_rules" && rules_ok=1
  cmp -s "$src_unit" "$dst_unit" && unit_ok=1
  enabled="$(grove_provision_1_12_firewall_unit_state is-enabled)"
  active="$(grove_provision_1_12_firewall_unit_state is-active)"

  if [[ $rules_ok -eq 1 && $unit_ok -eq 1 && "$enabled" == enabled && "$active" == active ]]; then
    echo "   • firewall declared, armed at boot, and loaded — no work"
    return 0
  fi

  bundle.root.owns "the host firewall" \
    "ruleset current: $([[ $rules_ok -eq 1 ]] && echo yes || echo no) · unit current: $([[ $unit_ok -eq 1 ]] && echo yes || echo no) · enabled: $enabled · active: $active" \
    || return 0

  ####################################################################
  # 1. check the repo's ruleset against THIS kernel before any write
  ####################################################################
  local checked
  if ! checked="$(sudo /usr/sbin/nft -c -f "$src_rules" 2>&1)"; then
    echo "   ✋ ConstraintError: this kernel rejects the repo's ruleset — no file was written" >&2
    printf '%s\n' "$checked" | sed 's/^/      /' >&2
    echo "      ⇒ the box keeps whatever firewall it had; a unit that fails at boot is worse" >&2
    echo "      fix: correct $src_rules, then: $(grove_provision_1_12_firewall_rerun)" >&2
    return 1
  fi

  ####################################################################
  # 2. the declaration — only the files that differ
  ####################################################################
  local rules_changed=0
  if [[ $rules_ok -eq 0 ]]; then
    if ! sudo install -D -m 0644 "$src_rules" "$dst_rules"; then
      echo "   💥 MalfunctionError: could not write $dst_rules" >&2
      echo "      read why: ls -ld $(dirname "$dst_rules")" >&2
      return 1
    fi
    rules_changed=1
    echo "   • ruleset declared: $dst_rules"
  fi

  if [[ $unit_ok -eq 0 ]]; then
    if ! sudo install -m 0644 "$src_unit" "$dst_unit" || ! sudo systemctl daemon-reload; then
      echo "   💥 MalfunctionError: could not declare $dst_unit" >&2
      echo "      read why: systemctl status $unit" >&2
      return 1
    fi
    echo "   • unit declared: $dst_unit"
  fi

  ####################################################################
  # 3. armed at boot
  ####################################################################
  if [[ "$(grove_provision_1_12_firewall_unit_state is-enabled)" != enabled ]]; then
    if ! sudo systemctl enable "$unit" >/dev/null 2>&1; then
      echo "   💥 MalfunctionError: could not enable $unit — the firewall would not load at boot" >&2
      echo "      read why: sudo systemctl enable $unit" >&2
      return 1
    fi
    echo "   • $unit enabled — it loads before any network, at every boot"
  fi

  ####################################################################
  # 4. loaded now — start where inactive, reload where the ruleset changed
  ####################################################################
  local verb=""
  [[ "$(grove_provision_1_12_firewall_unit_state is-active)" != active ]] && verb=start
  [[ -z "$verb" && $rules_changed -eq 1 ]] && verb=reload
  if [[ -n "$verb" ]]; then
    if ! sudo systemctl "$verb" "$unit"; then
      echo "   💥 MalfunctionError: $unit did not $verb — the ruleset is declared, and NOT live" >&2
      echo "      ⇒ inbound is open this boot; the next boot tries again" >&2
      echo "      read why: journalctl -u $unit -n 30" >&2
      return 1
    fi
    echo "   • firewall loaded ($verb) — no connection comes in"
  fi
}
