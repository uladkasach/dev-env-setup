#!/usr/bin/env bash
######################################################################
# .what = install the switch, its sudoers grant, and its NetworkManager hook
#
# .why each file is read before root is asked for
#   - all three match the repo → no work, and no root asked for
#
# .why the sudoers file is checked BEFORE it lands
#   - a sudoers file that does not parse locks every admin out of sudo.
#     `visudo -cf` parses the repo copy first; a reject writes naught
#
# guarantee:
#   - idempotent: each file is written only where it differs
#   - declines on every tier but `local@unix`, and where this seat holds no
#     root (`bundle.root.owns`)
######################################################################

grove_provision_1_13_exitnode_configure_upsert() {
  grove_provision_1_13_exitnode_applies || return 0

  local dir name dst mode stale=()
  dir="$(grove_provision_1_13_exitnode_dir)"

  # 0. what already holds — free reads, no root
  while read -r name dst mode; do
    grove_provision_1_13_exitnode_matches "$dir/$name" "$dst" "$mode" || stale+=("$name $dst $mode")
  done < <(grove_provision_1_13_exitnode_files)

  if [[ ${#stale[@]} -eq 0 ]]; then
    echo "   • switch, sudoers grant, and portal hook all current — no work"
    return 0
  fi

  bundle.root.owns "the exit-node switch" \
    "stale: $(printf '%s ' "${stale[@]%% *}")" \
    || return 0

  # 1. the sudoers grant must parse before any file lands
  local checked
  if ! checked="$(sudo visudo -cf "$dir/grove-exitnode.sudoers" 2>&1)"; then
    echo "   ✋ ConstraintError: visudo rejects the repo's sudoers grant — no file was written" >&2
    printf '%s\n' "$checked" | sed 's/^/      /' >&2
    echo "      fix: correct $dir/grove-exitnode.sudoers, then: $(grove_provision_1_13_exitnode_rerun)" >&2
    return 1
  fi

  # 2. the stale files, root-owned. the switch lands before the grant that names it
  local line
  for line in "${stale[@]}"; do
    read -r name dst mode <<<"$line"
    if ! sudo install -D -o root -g root -m "$mode" "$dir/$name" "$dst"; then
      echo "   💥 MalfunctionError: could not write $dst" >&2
      return 1
    fi
    echo "   • declared: $dst ($mode)"
  done
  echo "   • ⇒ \`use.vpn.switch on\` and \`use.vpn.switch off\` need no password; a captive portal pauses the vpn, and sign-in resumes it"
}
