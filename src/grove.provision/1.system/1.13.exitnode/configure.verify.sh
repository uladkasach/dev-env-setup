#!/usr/bin/env bash
######################################################################
# .what = prove the switch, its grant, and its hook each match the repo, and
#         that NetworkManager runs a connectivity check (the hook's only trigger)
#
# guarantee:
#   - READ-ONLY
######################################################################

grove_provision_1_13_exitnode_configure_verify() {
  grove_provision_1_13_exitnode_applies || return 0

  local dir name dst mode bad=0
  dir="$(grove_provision_1_13_exitnode_dir)"

  while read -r name dst mode; do
    if grove_provision_1_13_exitnode_matches "$dir/$name" "$dst" "$mode"; then
      echo "   • $dst matches the repo, mode $mode, root-owned ✔"
    else
      echo "   ✋ ConstraintError: $dst is $([[ -e "$dst" ]] && echo "not the repo copy at mode $mode, root-owned (it reads: $(stat -c '%a %U' "$dst" 2>/dev/null))" || echo 'absent')" >&2
      bad=1
    fi
  done < <(grove_provision_1_13_exitnode_files)
  if [[ $bad -eq 1 ]]; then
    echo "      fix: $(grove_provision_1_13_exitnode_rerun)" >&2
    return 1
  fi

  # the hook fires only on a connectivity-change, and NetworkManager raises
  # that only where a check uri is set
  local uri
  uri="$(timeout 5 NetworkManager --print-config 2>/dev/null | sed -n '/^\[connectivity\]/,/^\[/{s/^uri=//p}' | head -n 1)"
  if [[ -z "$uri" ]]; then
    echo "   ✋ ConstraintError: NetworkManager runs no connectivity check — a captive portal is never seen, so the pause never fires" >&2
    echo "      ⇒ set [connectivity] uri= in /etc/NetworkManager/conf.d/ (pop-os ships one at /usr/lib/NetworkManager/conf.d/20-connectivity-pop.conf)" >&2
    return 1
  fi
  echo "   • NetworkManager checks connectivity against $uri — a portal is seen ✔"
}
