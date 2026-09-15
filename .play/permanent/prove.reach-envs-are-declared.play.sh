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
#   - a row is `<org>:<env>:<reader>:<accountKey>:<roleKey>`, and both halves of
#     the bundle split it the same way
#   - a short row makes `${rest##*:}` hand back some EARLIER field, which names
#     no declaration — so the role reads EMPTY and the bundle declines with
#     "infrastructure is not cloned yet"
#   - ⇒ a plausible cause, for a defect that is in the table
#
# 🛑 .why the READER field is graded, and it is the newest claim here
#   - a row names which declaration source resolves its last two fields, and
#     `_role`/`_account` REFUSE an unknown one rather than fall back
#   - ⇒ a typo'd reader makes every read empty, so the bundle declines with
#     "not readable here" — the shape of an absent clone, for a table defect
#   - 📜 the demo row named `declmap` keys for a day. infra's own fulcrum
#     FORBIDS an org-shaped key in `GROVE_ROLE_NAME`, so that decline pointed
#     a human at a file that will never carry the answer
#   - (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.4)
#
# 🛑 .why the row's org is the TARGET org, and this play grades it as such
#   - `5.13.reach` parts two axes: `_srcorg` (whose clones DECLARE the role and
#     the account) from the row's org (whose account the profile REACHES)
#   - ⇒ a row may name an org whose own clones declare no account, and still be
#     correct — so this play asks `5.12.rack` about the row's OWN org, and
#     never about `_srcorg`
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

####################################################################
# 🛑 the declaration is read PER ROW's org, never once for the table
#   - a row carries its own TARGET org as of 2026-09-13, so one hoisted read
#     would grade every row against whichever org the first row happened to
#     name — and a correct ehmpathy row would report "NOT declared by ahbode"
#   - ⇒ the cache below keys on org, so each org's reader is still called once
####################################################################
_declared_for() {
  local o="$1" line
  while read -r line; do
    [[ "${line%%=*}" == "$o" ]] || continue
    printf '%s' "${line#*=}"
    return 0
  done <<< "$declared_cache"

  local d
  d="$(grove_provision_5_12_rack_declared "$o" 2>/dev/null)" || d=""
  declared_cache="$declared_cache$o=$d"$'\n'
  printf '%s' "$d"
}
declared_cache=""

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
#
# 🛑 .and the gate is PER READER, because the two read DIFFERENT FILES
#   - a `declmap` row needs `GROVE_ROLE_NAME` in `resources.role-names.ts`
#   - an `arnconst` row needs its pair of plain consts in `resources.reach-arns.ts`
#   - ⇒ one gate over one file would grade an `arnconst` row against a block it
#     never reads: 🌙 where the answer is in hand, or ✋ where it is not
####################################################################
rolesrc="$(grove_provision_5_13_reach_rolesrc)"
arnsrc="$(grove_provision_5_13_reach_arnsrc)"

readable_declmap="no"
if [[ -f "$rolesrc" ]] &&
   grep 'export const GROVE_ROLE_NAME' "$rolesrc" >/dev/null 2>&1; then
  readable_declmap="yes"
fi

####################################################################
# 🛑 `arnconst` has NO BLOCK to anchor on, so its gate is derived
#
# .the asymmetry, and why it is a property of the two SOURCES
#   - `declmap`'s keys sit INSIDE `GROVE_ROLE_NAME`, a closed container. so a
#     present block with an absent key IS a table defect — the gate has teeth
#   - `arnconst`'s keys are TOP-LEVEL consts beside an arn builder. the file
#     predates them and will outlive them, so its mere presence proves naught
#   - ⇒ `grep '^export const'` passes on a clone that is years behind, and the
#     row then ✋s for a fact that lives in another repo's unmerged branch
#   - 📜 measured 2026-09-14: infra's `origin/main` carries that file with
#     three account consts and NEITHER of the demo pair. the pair sits on an
#     unmerged branch, so the ✋ named a defect in a table that was correct
#   - (`gotcha.a-check-that-cries-wolf-gets-silenced`, the false-✋ half)
#
# .so the anchor is DERIVED from the table, never a key typed in here
#   - readable ⇔ at least ONE key this table reads via `arnconst` answers
#   - none answer  → the file predates the change → 🌙, and no row reddens
#   - one answers, another does not → the change LANDED and a key is wrong
#     → ✋, and the teeth are back exactly where they belong
#   - ⇒ a hardcoded anchor here would be a SECOND holder of `_envs`'s own
#     fact, free to drift the day a third arnconst row lands (m.9)
####################################################################
readable_arnconst="no"
if [[ -f "$arnsrc" ]]; then
  for _probe in $(grove_provision_5_13_reach_envs); do
    _prest="${_probe#*:}"; _prest="${_prest#*:}"      # drop org, drop env
    [[ "${_prest%%:*}" == "arnconst" ]] || continue
    _prest="${_prest#*:}"                              # drop reader
    for _pkey in "${_prest%%:*}" "${_prest##*:}"; do
      [[ -n "$(grove_provision_5_13_reach_tsconst "$arnsrc" "$_pkey")" ]] || continue
      readable_arnconst="yes"
      break 2
    done
  done
fi

# .what = is THIS row's declaration source readable on this box?
# 🛑 an unknown reader answers "no", and the row's own 1c arm ✋s it — so an
#      unreadable clone and a typo'd reader never collapse into one verdict
_readable_for() {
  case "${1:-}" in
    declmap)  [[ "$readable_declmap"  == "yes" ]] ;;
    arnconst) [[ "$readable_arnconst" == "yes" ]] ;;
    *) return 1 ;;
  esac
}

# .what = is this reader a name the bundle actually dispatches?
# .why  = the readable gate cannot say it — an unknown reader and an absent
#         clone both answer "no", and they owe opposite verdicts
_reader_is_known() {
  grove_provision_5_13_reach_declsrc "${1:-}" >/dev/null 2>&1
}

####################################################################
# 1. every row: well formed, declared, and (where readable) role-backed
####################################################################
seen_roles=""
proven_any="no"
for pair in $(grove_provision_5_13_reach_envs); do
  # 1a. the row must carry all five fields
  if [[ "$pair" != *:*:*:*:* ]]; then
    echo "   ✋ '${pair}': the row is malformed"
    echo "      ⇒ a row is '<org>:<env>:<reader>:<accountKey>:<roleKey>'"
    fails=$((fails + 1))
    continue
  fi
  org="${pair%%:*}"
  rest="${pair#*:}"
  env="${rest%%:*}"
  rest="${rest#*:}"
  reader="${rest%%:*}"
  rest="${rest#*:}"
  akey="${rest%%:*}"
  rkey="${rest##*:}"

  ####################################################################
  # 1a'. the reader must be one the bundle DISPATCHES
  #
  # 🛑 this is graded BEFORE the readability gate, and the order is the claim
  #   - an unknown reader makes `_readable_for` answer "no", exactly as an
  #     absent clone does — so a readability-first read would report a TYPO as
  #     🌙 "unproven here" and pass the table
  #   - ⇒ a typo'd reader must be a ✋ on EVERY box, clone or no clone
  ####################################################################
  if ! _reader_is_known "$reader"; then
    echo "   ✋ '${pair}': reader '${reader}' is not one 5.13.reach dispatches"
    # ⚠️ single quotes: a backtick inside "…" is a COMMAND SUBSTITUTION, so
    #    `_role` would run the function and print its refusal instead of its name
    echo '      ⇒ _role and _account REFUSE it, so both reads come back'
    echo "        empty — which reads as 'the clone is absent', on every box"
    echo '      ⇒ the readers are declared in 5.13.reach/_.sh, in _declsrc'
    fails=$((fails + 1))
    continue
  fi

  # 1b. the env must be a legal rack name FOR ITS OWN ORG, or its set is refused
  declared="$(_declared_for "$org")"
  if [[ -z "$declared" ]]; then
    ##################################################################
    # 🛑 an org 5.12.rack does not know is a READER fault, not a row fault
    #   - `_declared` returns 1 on an unknown org, so an empty read here is
    #     either a renamed reader or an org nobody declared
    #   - ⇒ to fall through would print "NOT declared" against every env of
    #     that org — a specific, plausible ✋ that names the wrong file
    #   - 📜 the same shape once fired on three correct rows after
    #     `_awsprofile_envs_declared` became `_declared <org>`
    #   - (`gotcha.a-check-that-cries-wolf-gets-silenced`, the false-✋ half)
    ##################################################################
    decl="✋ 5.12.rack declares NO envs for org '$org'"
    fails=$((fails + 1))
  elif [[ " $declared " == *" $env "* ]]; then
    decl="✔ declared"
  else
    decl="✋ NOT declared by 5.12.rack"
    fails=$((fails + 1))
  fi

  # 1c. the role key must name a real role, in THIS row's reader's own source
  if _readable_for "$reader"; then
    proven_any="yes"
    role="$(grove_provision_5_13_reach_role "$reader" "$rkey")"
    if [[ -z "$role" ]]; then
      rolesay="✋ ${reader} declares no role for '${rkey}'"
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
    rolesay="🌙 unproven (${reader}'s source is not readable here)"
  fi

  printf '   %-9s %-5s  %-9s akey=%-19s rkey=%-21s %s  role: %s\n' \
    "$org" "$env" "$reader" "$akey" "$rkey" "$decl" "$rolesay"
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
# 2b. an UNKNOWN reader must refuse, in BOTH readers
#
# 🛑 the `*)` arm is what makes the reader field load-bear
#   - with no `*)`, a future reader name falls through to whichever arm sits
#     first, and answers one row's key out of the other row's FILE
#   - ⇒ it would hunt `ACCOUNT_ID_DEMO` in a declapract.use.yml, find none,
#     and decline with a reason that names the wrong repo
#   - (`rule.forbid.failhide`)
####################################################################
if grove_provision_5_13_reach_role 'nosuchreader' 'prepPower' >/dev/null 2>&1; then
  echo "   ✋ a role read with an UNKNOWN reader ANSWERED — the fallback is back"
  fails=$((fails + 1))
else
  echo "   ✔ a role read with an unknown reader refuses"
fi

if grove_provision_5_13_reach_account 'nosuchreader' 'prep' >/dev/null 2>&1; then
  echo "   ✋ an account read with an UNKNOWN reader ANSWERED — the fallback is back"
  fails=$((fails + 1))
else
  echo "   ✔ an account read with an unknown reader refuses"
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
if [[ "$proven_any" == "yes" ]]; then
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
  echo "   🌙 the per-tier split is unproven — NO row's source was readable here"
  echo "      ⇒ the clone is absent, or present and behind. both read the same"
  echo "        way to this play, and neither is a defect in THIS repo"
  echo "      ⇒ read it on a box whose clone carries both:"
  echo "        $rolesrc"
  echo "        $arnsrc"
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
