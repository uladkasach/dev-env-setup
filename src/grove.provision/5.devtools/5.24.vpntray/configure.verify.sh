#!/usr/bin/env bash
######################################################################
# .what = prove the shield is built from the repo's source, declared to start
#         at every login, and that tailscale's retired tray is gone
#
# .why the verdict is declared state, and the live shield is context
#   - the binary, its stamp, and the entry are what hold after a reboot
#     (`rule.require.judge-declared-state-not-live-state`)
#   - a shield that is down now may be a shell with no session, a human who
#     quit it, or a login not yet made — each harmless, so none is a ✋
#
# guarantee:
#   - READ-ONLY
######################################################################

grove_provision_5_24_vpntray_configure_verify() {
  grove_provision_5_24_vpntray_applies || return 0

  local dir bin entry stamp legacy
  dir="$(grove_provision_5_24_vpntray_dir)"
  bin="$(grove_provision_5_24_vpntray_bin_at)"
  entry="$(grove_provision_5_24_vpntray_entry_at)"
  stamp="$(grove_provision_5_24_vpntray_stamp_at)"
  legacy="$(grove_provision_5_24_vpntray_legacy_entry_at)"
  local fix="rhx grove.provision --what 5.24.vpntray --mode apply"

  if [[ ! -x "$bin" ]]; then
    echo "   ✋ ConstraintError: $bin is absent — the shield is not built" >&2
    echo "      fix: $fix" >&2
    return 1
  fi
  if [[ "$(cat "$stamp" 2>/dev/null)" != "$(grove_provision_5_24_vpntray_src_hash)" ]]; then
    echo "   ✋ ConstraintError: $bin was built from other source than the repo's" >&2
    echo "      fix: $fix" >&2
    return 1
  fi
  echo "   • binary built from the repo's source ✔"

  if ! cmp -s "$dir/grove-vpntray.desktop" "$entry"; then
    echo "   ✋ ConstraintError: $entry is $([[ -e "$entry" ]] && echo 'not the repo copy' || echo 'absent') — the shield does not start at login" >&2
    echo "      fix: $fix" >&2
    return 1
  fi
  echo "   • autostart entry matches the repo — the shield starts at every login ✔"

  if [[ -e "$legacy" ]]; then
    echo "   ✋ ConstraintError: $legacy still starts tailscale's own tray at login" >&2
    echo "      fix: $fix" >&2
    return 1
  fi
  echo "   • tailscale's own tray is retired ✔"

  local pid
  pid="$(grove_provision_5_24_vpntray_pid)"
  if [[ -n "$pid" ]]; then
    echo "   • shield up now (pid $pid)"
  else
    echo "   🌙 shield not up this session — it starts at the next login"
  fi
}
