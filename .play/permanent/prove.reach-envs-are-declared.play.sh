#!/usr/bin/env bash
######################################################################
# .what = prove that every env `5.13.reach` wires is also DECLARED by
#         `5.12.rack`, and that each row of the reach table is well formed
#
# .why  = one fact — "which envs does this box reach?" — has TWO holders:
#
#           5.13.reach  `_envs`             the rows it WIRES
#           5.12.rack   `_declared <org>`   the names the rack accepts
#
#         they are free to drift, and the drift is silent in the direction
#         that costs most: a row wired with no declaration writes the profile
#         BODY into ~/.aws/config and then fails on the rack NAME. that is the
#         half-applied pair `aws.reach.set` exists to prevent, reintroduced one
#         layer up — and the box is left with a profile no consumer names.
#         (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
#
# .why the ROW SHAPE is proven too
#   - a row is `<env>:<declapractKey>:<roleKey>`, and both readers split it
#   - a 2-field row makes `${rest##*:}` hand back the DECLAPRACT key, which
#     names no `GROVE_ROLE_NAME` entry — so the role reads EMPTY and the
#     bundle declines with "infrastructure is not cloned yet"
#   - ⇒ a plausible cause, for a defect that is in the table
#
# 🛑 .why the ROLE NAMES are proven only where the BLOCK is READABLE
#   - the names live in `ahbode/infrastructure`, which a laptop may not hold
#   - ⇒ a hard fail there reddens on a box with no defect, and a check that
#     argues against correct trees gets silenced
#   - ⚠️ "readable", never "cloned": a PRESENT clone can sit behind, and then
#     the file exists with no `GROVE_ROLE_NAME` in it. absent and stale are
#     one fact to this reader, and both must DECLINE
#   - so that half SKIPS, loudly, and says which fact went unproven
#
# 🛑 it PRINTS no account id — this repo is PUBLIC
#   (`rule.forbid.dox-in-public-repo`)
#
# guarantee:
#   - READ-ONLY: it sources two `_.sh` files and writes not one byte
#   - exit 0 = every row is well formed and declared
#   - exit 1 = a row drifted, and the message names which
#   - exit 2 = the SUBJECT could not be read, so no claim was proven
######################################################################
set -uo pipefail

echo "🔎 prove.reach-envs-are-declared"
echo "   └─ subject: 5.13.reach's env table, against 5.12.rack's declaration"
echo ""

####################################################################
# 0. find the checkout by a FILE IT HOLDS, never by how it ARRIVED
#
# 🛑 `git rev-parse` alone is false on every grove
#   - the provision PUSHES `src/`, so a grove's checkout carries no `.git`
#   - ⇒ `--show-toplevel` fails, ROOT is empty, and both sources expand to
#     `/src/...` — paths that exist on no box
#   - 📜 measured 2026-09-06 on grove-ahbode-v20260901, sent via `--play`:
#
#       fatal: not a git repository (or any of the parent directories): .git
#       line 47: /src/grove.provision/5.devtools/5.13.reach/_.sh: No such file
#
#   - ⇒ this is `define.provision-defect-shapes`, the EIGHTH shape: a check
#     that keys on how the repo arrived, not on what it holds. it is true on
#     the laptop that wrote it and false on every box it was written for
#   - (`rule.require.one-command-provision`, its `.git`-as-proxy clause)
#
# ⚠️ the sent play lives in `$HOME/.local/state/grove.play/`, detached from
#    the checkout — so `BASH_SOURCE`-relative cannot reach it either
####################################################################
_holds_subject() { [[ -f "$1/src/grove.provision/5.devtools/5.12.rack/_.sh" ]]; }

ROOT=""
for cand in \
  "$(git rev-parse --show-toplevel 2>/dev/null || true)" \
  "$HOME/git/more/dev-env-setup" \
  "$PWD"
do
  [[ -n "$cand" ]] || continue
  if _holds_subject "$cand"; then ROOT="$cand"; break; fi
done

if [[ -z "$ROOT" ]]; then
  echo "   🌙 no checkout in reach holds 5.12.rack/_.sh, so the subject is unread" >&2
  echo "      ⇒ this proves no part of either table — it reports that neither" >&2
  echo "        could be opened, which is a different fact" >&2
  echo "      ⇒ run it from inside a dev-env-setup checkout, or on a box whose" >&2
  echo "        push landed at \$HOME/git/more/dev-env-setup" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "$ROOT/src/grove.provision/5.devtools/5.13.reach/_.sh"
# shellcheck source=/dev/null
source "$ROOT/src/grove.provision/5.devtools/5.12.rack/_.sh"

fails=0
org="$(grove_provision_5_13_reach_org)"
declared="$(grove_provision_5_12_rack_declared "$org")"

####################################################################
# 🛑 an EMPTY read halts here, and never falls through to the rows
#   - `set -u` does not fire on a command that does not exist, so a renamed
#     reader leaves `declared=''` and exits 127 into a `$(...)` nobody checks
#   - ⇒ every row below then reads "NOT declared" — a SPECIFIC, plausible ✋
#     against a tree that is correct, which is the shape that gets a check
#     silenced rather than read
#   - 📜 measured: `_awsprofile_envs_declared` became `_declared <org>`, and
#     this play reported 3 drifted rows on a tree whose grove had just proven
#     all of them live
#   - (`gotcha.a-check-that-cries-wolf-gets-silenced`, the false-✋ half)
####################################################################
if [[ -z "$declared" ]]; then
  echo "   ✋ 5.12.rack declares no envs for '$org' — the READER is broken, not the tree" >&2
  echo "      ⇒ this play sources 5.12.rack/_.sh and asks it for '$org'" >&2
  echo "      ⇒ a rename there leaves this empty, and every row below would" >&2
  echo "        read 'NOT declared' against envs that are present" >&2
  echo "      fix: reconcile this call with 5.12.rack/_.sh's own function name" >&2
  exit 1
fi

####################################################################
# 🛑 the gate is "can the BLOCK be read", never "does the FILE exist"
#   - a clone can be PRESENT and behind, and a stale checkout carries the
#     file with no `GROVE_ROLE_NAME` in it — so every role reads empty
#   - ⇒ a file-existence gate calls that a DEFECT IN THE TABLE, and names a
#     fix in this repo for a fact that lives in another repo's checkout
#   - 📜 measured on this laptop: `origin/main` declares the block, and the
#     local tree held only a comment that mentions it. all three rows went ✋
#     minutes after a grove read every one of those roles live
#   - ⇒ absent and stale are ONE fact to this reader: the name is unreadable
#     here. both decline; neither reddens
#   - (`gotcha.a-check-that-cries-wolf-gets-silenced`, the false-✋ half)
####################################################################
rolesrc="$(grove_provision_5_13_reach_rolesrc)"
infra="no"
if [[ -f "$rolesrc" ]] &&
   grep 'export const GROVE_ROLE_NAME' "$rolesrc" >/dev/null 2>&1; then
  infra="yes"
fi

####################################################################
# 1. every row: well formed, declared, and (where readable) role-backed
####################################################################
seen_roles=""
for pair in $(grove_provision_5_13_reach_envs); do
  env="${pair%%:*}"
  rest="${pair#*:}"

  # 1a. the row must carry all three fields
  if [[ "$rest" != *:* ]]; then
    echo "   ✋ ${env}: the row names no role key"
    echo "      ⇒ a row is '<env>:<declapractKey>:<roleKey>'"
    fails=$((fails + 1))
    continue
  fi
  dkey="${rest%%:*}"
  rkey="${rest##*:}"

  # 1b. the env must be a legal rack name, or its set is refused
  if [[ " $declared " == *" $env "* ]]; then
    decl="✔ declared"
  else
    decl="✋ NOT declared by 5.12.rack"
    fails=$((fails + 1))
  fi

  # 1c. the role key must name a real GROVE_ROLE_NAME entry
  if [[ "$infra" == "yes" ]]; then
    role="$(grove_provision_5_13_reach_role "$rkey")"
    if [[ -z "$role" ]]; then
      rolesay="✋ GROVE_ROLE_NAME.${rkey} names no role"
      fails=$((fails + 1))
    elif [[ "$role" != *"-for-grove" ]]; then
      # every grove reach target carries the `-for-grove` slot; an OIDC role
      # does not. a name without it means the read took the wrong block
      rolesay="✋ read '$role' — not a grove reach role (the OIDC block?)"
      fails=$((fails + 1))
    else
      rolesay="✔ $role"
      seen_roles="$seen_roles$rkey=$role"$'\n'
    fi
  else
    rolesay="🌙 unproven (no GROVE_ROLE_NAME readable here)"
  fi

  printf '   %-5s  dkey=%-5s  rkey=%-10s  %s  role: %s\n' \
    "$env" "$dkey" "$rkey" "$decl" "$rolesay"
done

####################################################################
# 2. a role read with NO key must REFUSE, never fall back
#
# ⚠️ the default it once carried was `prepPower`. with prod in the table, a
#    silent fallback composes the PREP role name against the PROD account —
#    an arn that names no role, so it refuses exactly like an absent grant
####################################################################
echo ""
if grove_provision_5_13_reach_role >/dev/null 2>&1; then
  echo "   ✋ a role read with no key ANSWERED — the silent default is back"
  echo "      ⇒ it would compose the prep role against the prod account"
  fails=$((fails + 1))
else
  echo "   ✔ a role read with no key refuses"
fi

####################################################################
# 3. two DIFFERENT role keys must not read one role name
#
# 🛑 the pairs are DEDUPED first, and that is the whole claim
#   - `seen_roles` holds one line per ROW, and two rows may legitimately
#     share a key: `_envs` gives test and prep the same `prepPower`, since
#     test borrows prep's account (see `5.13.reach/_.sh`, its `.note`)
#   - ⇒ a tally over ROWS reads that one key, used twice, as a duplicated
#     ROLE — and reports the declared design as a drift
#   - 📜 measured 2026-09-06 on grove-ahbode-v20260901, the first run where
#     infrastructure was readable: all three roles read ✔ and this ✋ fired
#     against `ahbode-prep-for-grove`, on a table nobody had changed
#   - ⇒ `sort -u` over `key=role` PAIRS collapses one key's repeats to one
#     line, so a survivor duplicate means two DISTINCT keys — the claim
#   - ⚠️ the old `distinct_keys > 1` guard aimed at this and could not reach
#     it: it counted keys across the WHOLE table, never per duplicated role
#   - (`gotcha.a-check-that-cries-wolf-gets-silenced`, the false-✋ half)
####################################################################
echo ""
if [[ "$infra" == "yes" ]]; then
  pairs="$(printf '%s' "$seen_roles" | grep -v '^$' | sort -u)"
  dupes="$(printf '%s\n' "$pairs" | grep -v '^$' | cut -d= -f2 | sort | uniq -d)"
  if [[ -n "$dupes" ]]; then
    echo "   ✋ two DIFFERENT role keys read the same role name:"
    printf '%s\n' "$dupes" | sed 's/^/        /'
    echo "      ⇒ the per-tier split is what the roleKey column exists for"
    fails=$((fails + 1))
  else
    echo "   ✔ each role key reads its own distinct role"
  fi
else
  echo "   🌙 the per-tier split is unproven — no GROVE_ROLE_NAME readable here"
  echo "      ⇒ the clone is absent, or present and behind. both read the same"
  echo "        way to this play, and neither is a defect in THIS repo"
  echo "      ⇒ read it on a box whose clone carries the block:"
  echo "        $rolesrc"
  echo "      ⇒ compare the two without a direct read of that checkout:"
  echo "        rhx git.repo.get lines --in ahbode/infrastructure \\"
  echo "          --paths 'provision/aws.auth/resources.role-names.ts' \\"
  echo "          --words 'GROVE_ROLE_NAME'          # origin/main"
  echo "        …the same call with --tree main       # this clone, inflight"
fi

echo ""
if [[ $fails -eq 0 ]]; then
  echo "🌲 prove.reach-envs-are-declared ✔"
  exit 0
fi
echo "🌲 prove.reach-envs-are-declared — $fails claim(s) did not hold ✋" >&2
exit 1
