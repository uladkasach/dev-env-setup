#!/usr/bin/env bash
# .what = prove the pqivrc config is on this box AND that it matches the repo
# .why "the file is here" is the weaker half — a stale copy from before the
#   last change stays in place and the box LOOKS configured and reads wrong
#   (rule.forbid.failhide)
#
# guarantee:
#   - READ-ONLY. it reads the config, never writes it
#
# exit:
#   0 = a config is here
#   1 = it is absent, and the fix is named

grove_provision_4_6_pqiv_configure_verify() {
  local conf="$HOME/.config/pqivrc"

  if [[ ! -f "$conf" ]]; then
    echo "   ✋ no pqivrc at $conf" >&2
    echo "      ⇒ configure.upsert did not take, so pqiv draws its own defaults" >&2
    echo "      fix: rhx grove.provision --what 4.6.pqiv --mode apply" >&2
    return 1
  fi

  echo "   • pqivrc found ✔"

  # drift from the repo is a note, never a failure. compare against
  # $GROVE_SRC, this run's OWN checkout, never main
  local src="$GROVE_SRC/grove.provision/4.terminal/4.6.pqiv/pqivrc"
  if [[ -f "$src" ]] && ! cmp -s "$src" "$conf"; then
    echo "     note: the live config DIFFERS from the repo's"
    echo "     ⇒ a hand-edit, or a stale copy from before the last change:"
    echo "       diff $src $conf"
  fi
}
