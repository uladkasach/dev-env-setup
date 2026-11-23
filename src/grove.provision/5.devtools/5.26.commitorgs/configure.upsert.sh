#!/usr/bin/env bash
######################################################################
# .what = allow each org this grove's token can push to, in the seat's org commit
#         meter — only where the org is unset
#
# .why  = the token's push scope is the grant; this writes it where the commit gate
#         reads it, so the first crew of each org commits with no hand step
#
# guarantee:
#   - a blocked org is left as is; a damaged meter is never written over
#   - every other key in the meter is kept
#   - it re-reads the meter after the write and proves each grant landed
#   - idempotent: a meter that allows every org takes no write
######################################################################

grove_provision_5_26_commitorgs_configure_upsert() {
  grove_provision_5_26_commitorgs_declines >/dev/null && return 0
  grove_provision_5_26_commitorgs_refuses_without_jq && return 1

  local seat orgs presence bytes='' states unset_orgs damaged_orgs blocked_orgs left org state
  seat="$(whoami)@$(hostname)"

  if ! orgs="$(grove_provision_5_26_commitorgs_token_orgs)"; then
    echo "   ✋ ConstraintError: the github token on $seat could not be read, so the orgs it may push to are unknown" >&2
    echo "      ├─ asked: gh api user/repos (bounded at ${GROVE_COMMITORGS_GH_SECONDS}s)" >&2
    echo "      └─ fix: rhx grove.provision --what 5.4.gh --mode apply   # it wires gh to the token" >&2
    return 1
  fi
  [[ -n "$orgs" ]] || { echo "   🌙 the token on $seat can push to no org — none to allow"; return 0; }

  presence="$(grove_provision_5_26_commitorgs_meter_presence)"
  grove_provision_5_26_commitorgs_refuses_unreadable "$presence" "$seat" && return 1
  if [[ "$presence" == "present" ]] && ! bytes="$(grove_provision_5_26_commitorgs_meter_bytes)"; then
    echo "   💥 MalfunctionError: the org commit meter on $seat is present, and could not be read" >&2
    echo "      ├─ file: $(grove_provision_5_26_commitorgs_meter_path)" >&2
    echo "      ├─ read why: ls -l $(grove_provision_5_26_commitorgs_meter_path)   # a mode or owner fault fails every re-run" >&2
    echo "      └─ fix: once it reads, re-run — rhx grove.provision --what 5.26.commitorgs --mode apply" >&2
    return 1
  fi

  states="$(grove_provision_5_26_commitorgs_states_of orgs="$orgs" presence="$presence" bytes="$bytes")"
  damaged_orgs="$(grove_provision_5_26_commitorgs_orgs_in states="$states" in=corrupt)"
  unset_orgs="$(grove_provision_5_26_commitorgs_orgs_in states="$states" in=unset)"

  # a damaged meter may hold a block, so it is read by a human before any write
  if [[ -n "$damaged_orgs" ]]; then
    echo "   ✋ ConstraintError: the org commit meter on $seat is damaged, so no grant is written over it" >&2
    grove_provision_5_26_commitorgs_damaged_fix "$seat"
    return 1
  fi

  # a block is the human's word: said, and left as is
  blocked_orgs="$(grove_provision_5_26_commitorgs_orgs_in states="$states" in='blocked blocked@all')"
  while IFS='=' read -r org state; do
    [[ "$state" == blocked || "$state" == blocked@all ]] || continue
    echo "   🌙 left org '$org' as is on $seat — the human blocked it$(grove_provision_5_26_commitorgs_scope_of "$state"); its crews are refused here until the human lifts it"
  done <<< "$states"

  if [[ -z "$unset_orgs" ]]; then
    [[ -n "$blocked_orgs" ]] || echo "   • every token org already reads allowed on $seat — no write owed"
    return 0
  fi

  local wrote=0
  grove_provision_5_26_commitorgs_meter_allow orgs="$unset_orgs" presence="$presence" bytes="$bytes" || wrote=$?
  if [[ "$wrote" -eq 3 ]]; then
    echo "   ✋ ConstraintError: the org commit meter on $seat changed while this apply ran, so no grant is written over it" >&2
    echo "      ├─ why: a block a human (or a second apply) set in that moment would be lost" >&2
    echo "      └─ fix: re-run — rhx grove.provision --what 5.26.commitorgs --mode apply   # it reads the meter afresh" >&2
    return 1
  fi
  if [[ "$wrote" -ne 0 ]]; then
    echo "   ✋ ConstraintError: the org commit meter on $seat could not be written" >&2
    echo "      ├─ file: $(grove_provision_5_26_commitorgs_meter_path)" >&2
    echo "      ├─ read why: ls -ld \"$(dirname "$(grove_provision_5_26_commitorgs_meter_path)")\"; df -h \"\$HOME\"" >&2
    echo "      └─ fix: once the dir is writable and the disk has room, re-run — rhx grove.provision --what 5.26.commitorgs --mode apply" >&2
    return 1
  fi

  # prove the write: every org it meant to allow now reads allowed, the gate's way
  bytes="$(grove_provision_5_26_commitorgs_meter_bytes)" || bytes=''
  states="$(grove_provision_5_26_commitorgs_states_of orgs="$unset_orgs" presence="$(grove_provision_5_26_commitorgs_meter_presence)" bytes="$bytes")"
  left="$(grove_provision_5_26_commitorgs_orgs_in states="$states" in='unset corrupt blocked blocked@all')"
  if [[ -n "$left" ]]; then
    echo "   ✋ ConstraintError: the meter on $seat was written, and it still reads no grant for $(grove_provision_5_26_commitorgs_orgs_phrase_of "$left")" >&2
    echo "      ├─ file: $(grove_provision_5_26_commitorgs_meter_path)" >&2
    echo "      ├─ read why: cat $(grove_provision_5_26_commitorgs_meter_path)" >&2
    echo "      └─ fix: re-run — rhx grove.provision --what 5.26.commitorgs --mode apply; if it reads no grant again, the gate's own read names the gap: rhx git.commit.uses get --org" >&2
    return 1
  fi
  echo "   • allowed $(grove_provision_5_26_commitorgs_orgs_phrase_of "$unset_orgs") on $seat — the token can push to $(grove_provision_5_26_commitorgs_each_of "$unset_orgs")"
}
