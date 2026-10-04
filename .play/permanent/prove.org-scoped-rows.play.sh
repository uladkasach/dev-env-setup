#!/usr/bin/env bash
######################################################################
# .what = prove every per-org row targets its OWN org, or an opt-in this
#         play declares — and that an unknown org gets ZERO rows
#
# .why  = `rule.require.a-grove-reaches-its-own-org-only`, clamped
#
# 📜 .the measurement that bought this play — 2026-09-24
#   an aether grove refused five `sts:AssumeRole` calls. five tables across
#   three bundles held `ahbode` as a hardcoded scalar with no org axis, so
#   EVERY grove inherited ahbode's whole reach table by construction.
#
#   🛑 no check caught it, and every check was RIGHT. `prove.reach-envs-are-declared`
#   graded each row well formed and declared — which each was. the defect sat
#   one level up, in WHICH rows the table held at all, and no reader looked
#   there. so this play grades the axis that one does not.
#
#   ⇒ and its repair reads as "grant it": an infra ask was drafted to have
#     those five hops allowed, which would have bought an aether box a
#     permanent assume-role into ahbode prod to silence a correct refusal.
#     that is why the clamp is owed — the wrong fix writes itself.
#
# 🛑 .the org set is DERIVED, never typed here
#   - a typed org list is a second holder of the tables' own fact, and it goes
#     stale in silence the day a third org lands (m.9)
#   - a typed list also inherits its author's blind spot: a reader that cannot
#     see a form reports zero rows of it, and zero rows reads as a pass (q11)
#   - ⇒ `grove_org_tabled` reads the `case` arms out of each table itself
#   - 🛑 an EMPTY derivation is `exit 2`, never a pass — an unread subject and
#     a clean subject are two facts, and only one of them is good news
#
# ⚠️ .the ONE list under review is `OPTINS`, and that is deliberate
#   - clause 2 says a cross-org reach is an ENUMERATED opt-in, so the set of
#     them must be small, written down, and read by a human
#   - ⇒ a new pair here is the review. a new pair in a bundle with no pair
#     here reddens, which is the whole point
#
# 🛑 it PRINTS no account id — this repo is PUBLIC
#   (`rule.forbid.dox-in-public-repo`)
#
# guarantee:
#   - READ-ONLY: it sources four files and writes not one byte
#   - exit 0 = every row stays in its org, or in a reviewed opt-in
#   - exit 1 = a row crossed an org boundary nobody enrolled
#   - exit 2 = the SUBJECT could not be read, so no claim was proven
######################################################################
set -uo pipefail

echo "🔎 prove.org-scoped-rows"
echo "   └─ subject: every per-org table, against its own org and the opt-ins"
echo ""

####################################################################
# 0. find the checkout by a FILE IT HOLDS, never by how it ARRIVED
#
# 🛑 `git rev-parse` alone is false on every grove — the provision PUSHES
#    `src/`, so a grove's checkout carries no `.git` and ROOT reads empty
#    (`define.provision-defect-shapes`, the EIGHTH shape)
####################################################################
_holds_subject() { [[ -f "$1/src/grove.org.sh" ]]; }

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
  echo "   🌙 no checkout in reach holds src/grove.org.sh, so the subject is unread" >&2
  echo "      ⇒ this proves no part of any table — it reports that none could" >&2
  echo "        be opened, which is a different fact" >&2
  exit 2
fi

BUNDLES="$ROOT/src/grove.provision/5.devtools"
RACK="$BUNDLES/5.12.rack/_.sh"
REACH="$BUNDLES/5.13.reach/_.sh"
KEYS="$BUNDLES/5.16.keys/_.sh"
REPOS="$BUNDLES/5.10.repos/_.sh"
GATE="$ROOT/.agent/repo=.this/role=any/skills/git.grove.provision.test.sh"

for f in "$RACK" "$REACH" "$KEYS" "$REPOS" "$GATE"; do
  [[ -f "$f" ]] && continue
  echo "   🌙 a subject is absent: $f" >&2
  echo "      ⇒ the tree moved, and this play read a path that no longer holds" >&2
  exit 2
done

# shellcheck source=/dev/null
source "$ROOT/src/grove.org.sh"
# shellcheck source=/dev/null
source "$RACK"
# shellcheck source=/dev/null
source "$REACH"
# shellcheck source=/dev/null
source "$KEYS"
# shellcheck source=/dev/null
source "$REPOS"

####################################################################
# 🛑 the GATE is a skill, not a library — it RUNS when sourced
#
# every other subject here is a `_.sh` that only declares functions, so a
# `source` is free. the gate parses args, probes a box, and drives a suite.
#
# ⇒ so its ONE table is extracted and evaluated on its own. the extraction is
#   anchored at column 0 on the function's own header, and it FAILS LOUD if
#   the table is absent — a silently-unread table would sail through 2f as a
#   clean pass, which is the q11 defect this whole play exists to catch
####################################################################
_gate_table="$(sed -n '/^_target_repo_for_org() {/,/^}/p' "$GATE")"

if [[ -z "$_gate_table" ]]; then
  echo "   🌙 the gate declares no _target_repo_for_org this reader could see" >&2
  echo "      ⇒ two causes, and neither is a pass: the gate lost its per-org" >&2
  echo "        table, or the table moved to a shape this sed cannot read" >&2
  echo "      ⇒ read it: $GATE" >&2
  exit 2
fi

eval "$_gate_table"

fails=0

####################################################################
# ⚠️ THE REVIEWED LIST — a cross-org reach, one pair per line
#
# format = `<owner org>:<org it may target>`
#
# 🛑 each pair is a permanent cross-account grant somebody asked infra for,
#    so each owes a reason a human read and accepted:
#
#   ahbode:ehmpathy — ehmpathy's demo account is GENERIC INFRA, published for
#     any org to build against. ahbode's suites test against it, so ahbode
#     opted in. that says NOT ONE WORD about any other org: an opt-in is the
#     org's own decision and does not generalize
#
#   ahbode:whodisio — whodisio is the identity org ahbode's services
#     authenticate through. this pair RECORDS a reach this repo already had
#     (`5.10.repos` cloned whodisio onto every box since before the org axis
#     existed); it grants no new one. enrolled 2026-09-24 so a reviewer sees it
####################################################################
OPTINS='ahbode:ehmpathy ahbode:whodisio'

_may_target() {
  local own="$1" want="$2" pair
  [[ "$own" == "$want" ]] && return 0
  for pair in $OPTINS; do
    [[ "$pair" == "${own}:${want}" ]] && return 0
  done
  return 1
}

####################################################################
# ⚠️ THE SECOND REVIEWED LIST — a keyrack org's own GITHUB org
#
# format = `<keyrack org>:<github org>`
#
# 🛑 .why a second list at all, when the tables already hold the pairs
#   - the reach/rack/keys tables key on `GROVE_ORG` and their VALUES are also
#     keyrack orgs, so `own == want` grades them with no bridge
#   - the clone table and the gate's target are different: their values are
#     GITHUB orgs, a separate namespace
#   - 📜 measured 2026-09-24: `aether` is the keyrack org and
#     `aether-auctions` is the github org. an arm that assumed they agree
#     listed an org github does not have, and the empty result read as "the
#     token can see no repos here" — a true sentence about a nonexistent org
#   - ⇒ so the two namespaces need a declared bridge, and it is DECLARED here
#     rather than derived from the table, since a table graded against itself
#     proves naught
#
# ⚠️ an org absent from this list cannot be graded at all — 2e and 2f say so
#    and fail, rather than wave the row through (`rule.forbid.failhide`)
####################################################################
GHORGS='ahbode:ahbode aether:aether-auctions ehmpathy:ehmpathy whodisio:whodisio'

# .what = may an `$own` box hold repos of the GITHUB org `$ghorg`?
# .why  = it maps BACK to a keyrack org, then reuses the one `_may_target`
#         above — so the opt-in list has ONE holder, never two
_may_clone() {
  local own="$1" ghorg="$2" pair
  for pair in $GHORGS; do
    [[ "${pair#*:}" == "$ghorg" ]] && { _may_target "$own" "${pair%%:*}"; return $?; }
  done
  return 1
}

####################################################################
# 1. derive the org set off the tables themselves, and REFUSE an empty read
####################################################################
####################################################################
# 🛑 EVERY table contributes an arm, and a new table is added HERE first
#
# 📜 measured 2026-09-24, on this play's own extension. 2e and 2f were added
#    to grade `5.10.repos` and the gate, and this derivation was left at three
#    tables — so `aether`, which only those two declare, was never walked and
#    both new arms sailed through ungraded. the run printed 22 ✔ and a green
#    verdict over rows it never opened.
#
#    that is `gotcha.a-check-that-cries-wolf-gets-silenced` q11, committed by
#    the play written to catch q11, on the same afternoon it was written.
#
# ⇒ the rule it yields: a table added to section 2 is added to section 1 in
#   the SAME edit. the org set is the reader's REACH, and a row outside it
#   produces no row at all
####################################################################
orgs="$(
  {
    grove_org_tabled "$REACH" grove_provision_5_13_reach_envs
    grove_org_tabled "$RACK"  grove_provision_5_12_rack_declared
    grove_org_tabled "$KEYS"  grove_provision_5_16_keys_required
    grove_org_tabled "$REPOS" grove_provision_5_10_repos_orgs
    grove_org_tabled "$GATE"  _target_repo_for_org
  } 2>/dev/null | grep -v '^$' | sort -u
)"

if [[ -z "$orgs" ]]; then
  echo "   🌙 no table declared an org arm this reader could see" >&2
  echo "      ⇒ two causes, and neither is a pass: the tables carry no arms," >&2
  echo "        or the arms moved to a shape grove_org_tabled cannot read" >&2
  echo "      ⇒ read the case arms in each _.sh, then this reader" >&2
  exit 2
fi

echo "   🔭 orgs declared across the per-org tables:"
printf '%s\n' "$orgs" | sed 's/^/        /'
echo ""

####################################################################
# 2. every row of every org: its TARGET must be own-org or a reviewed opt-in
#
# 🛑 `GROVE_ORG` is set PER ORG and restored after, so this play leaves the
#    caller's environment exactly as it found it
####################################################################
_org_before="${GROVE_ORG:-}"

for org in $orgs; do
  export GROVE_ORG="$org"

  rows=0

  # 2a. 5.13.reach — `<org>:<env>:<reader>:<accountKey>:<roleKey>`
  for pair in $(grove_provision_5_13_reach_envs 2>/dev/null); do
    rows=$((rows + 1))
    target="${pair%%:*}"
    if _may_target "$org" "$target"; then
      printf '   ✔ %-9s 5.13.reach  → %-9s %s\n' "$org" "$target" "$pair"
    else
      printf '   ✋ %-9s 5.13.reach  → %-9s %s\n' "$org" "$target" "$pair"
      echo "      ⇒ a '${org}' grove has no business in a '${target}' account"
      echo "        and aws will refuse the hop, correctly"
      echo "      ⇒ the repair is to DELETE the row — never to seek the grant"
      echo "        (rule.require.a-grove-reaches-its-own-org-only)"
      echo "      ⇒ if the reach is genuinely owed, enroll '${org}:${target}'"
      echo "        in this play's OPTINS first, with the reason beside it"
      fails=$((fails + 1))
    fi
  done

  # 2b. 5.12.rack — `<org>:<env>,<env>`
  for row in $(grove_provision_5_12_rack_awsprofile_rows 2>/dev/null); do
    rows=$((rows + 1))
    target="${row%%:*}"
    if _may_target "$org" "$target"; then
      printf '   ✔ %-9s 5.12.rack   → %-9s %s\n' "$org" "$target" "$row"
    else
      printf '   ✋ %-9s 5.12.rack   → %-9s %s\n' "$org" "$target" "$row"
      echo "      ⇒ the rack would hold a '${target}' profile name on a"
      echo "        '${org}' box, for an account it may not reach"
      echo "      ⇒ delete the row, or enroll the pair in OPTINS with its reason"
      fails=$((fails + 1))
    fi
  done

  # 2c. 5.16.keys — `<org>:<env>:<key>`
  #
  # 🛑 a vendor key row carries a TARGET org exactly as a reach row does, and
  #    ahbode's arm holds SIX ehmpathy rows that ride its opt-in. so this table
  #    is on the same axis, and a cross-org key row must earn the same review
  for krow in $(grove_provision_5_16_keys_required 2>/dev/null); do
    rows=$((rows + 1))
    target="${krow%%:*}"
    if _may_target "$org" "$target"; then
      printf '   ✔ %-9s 5.16.keys   → %-9s %s\n' "$org" "$target" "$krow"
    else
      printf '   ✋ %-9s 5.16.keys   → %-9s %s\n' "$org" "$target" "$krow"
      echo "      ⇒ a '${org}' box would be told it MUST read a '${target}'"
      echo "        vendor key, and a key row is a hard requirement — so the"
      echo "        bundle fails rather than declines"
      echo "      ⇒ delete the row, or enroll the pair in OPTINS with its reason"
      fails=$((fails + 1))
    fi
  done

  # 2e. 5.10.repos — the CLONE set, as github orgs
  #
  # 🛑 a clone set is the WIDEST cross-org reach this repo has: a reach row
  #    buys one account, and a clone set buys every repo a token can see. so
  #    it earns the same review, on the same axis
  #
  # ⚠️ `GROVE_GIT_ORGS` is an override and would mask the table, so it is
  #    unset for this read — the play grades the DECLARATION, never a caller
  for ghorg in $(GROVE_GIT_ORGS= grove_provision_5_10_repos_orgs 2>/dev/null); do
    rows=$((rows + 1))
    if _may_clone "$org" "$ghorg"; then
      printf '   ✔ %-9s 5.10.repos  → %-9s (github)\n' "$org" "$ghorg"
    else
      printf '   ✋ %-9s 5.10.repos  → %-9s (github)\n' "$org" "$ghorg"
      echo "      ⇒ a '${org}' box would clone every repo of the github org"
      echo "        '${ghorg}' — the widest cross-org reach this repo can grant"
      echo "      ⇒ if '${ghorg}' is not in GHORGS, add it there first: an org"
      echo "        this play cannot map is an org it cannot grade"
      echo "      ⇒ otherwise delete the row, or enroll the pair in OPTINS"
      fails=$((fails + 1))
    fi
  done

  # 2f. the ACCEPTANCE GATE's target tree — `<github org>/<repo>`
  #
  # 🛑 a gate is the worst place for this defect: every other table wires a
  #    CAPABILITY, and this one decides what PASSING MEANS. an aether grove
  #    gated on ahbode's service reports ahbode's verdict as aether's
  if target_repo="$(_target_repo_for_org "$org" 2>/dev/null)" && [[ -n "$target_repo" ]]; then
    rows=$((rows + 1))
    ghorg="${target_repo%%/*}"
    if _may_clone "$org" "$ghorg"; then
      printf '   ✔ %-9s gate.target → %-9s %s\n' "$org" "$ghorg" "$target_repo"
    else
      printf '   ✋ %-9s gate.target → %-9s %s\n' "$org" "$ghorg" "$target_repo"
      echo "      ⇒ a '${org}' grove would be gated on '${target_repo}', so its"
      echo "        acceptance verdict would be about another org's code"
      echo "      ⇒ declare that org's own target, or enroll the pair in OPTINS"
      fails=$((fails + 1))
    fi

    ####################################################################
    # 🛑 and the target must be CLONEABLE on that box — step 1 refuses to
    #    clone, so a target outside the org's own clone set halts forever
    #    with a fix-text no apply can satisfy
    ####################################################################
    if ! printf '%s\n' $(GROVE_GIT_ORGS= grove_provision_5_10_repos_orgs 2>/dev/null) \
         | grep -qx "$ghorg"; then
      printf '   ✋ %-9s gate.target → %s is outside 5.10.repos'"'"'s clone set\n' \
        "$org" "$target_repo"
      echo "      ⇒ the clone is bundle-owned, so the gate halts at step 1 and"
      echo "        its fix names an apply that will never fetch this tree"
      echo "      ⇒ add '${ghorg}' to 5.10.repos's arm for '${org}', or retarget"
      fails=$((fails + 1))
    fi
  fi

  # 2d. an org that declares an arm must yield at least ONE row somewhere
  #
  # 🛑 this is the q11 guard, turned on this play itself: a reader that sees
  #    the arm and reads zero rows out of it has found a parse defect, not a
  #    clean table — and zero rows would otherwise sail through 2a and 2b
  if [[ $rows -eq 0 ]]; then
    echo "   ✋ ${org} declares an arm and yielded ZERO rows"
    echo "      ⇒ either the arm is empty, or this play read the wrong reader"
    echo "      ⇒ an empty arm is a table defect: delete the arm, or fill it"
    fails=$((fails + 1))
  fi
done

if [[ -n "$_org_before" ]]; then export GROVE_ORG="$_org_before"; else unset GROVE_ORG; fi

####################################################################
# 3. clause 3 — an org with no table gets no OTHER org's rows
#
# 🛑 the two probes are DIFFERENT states and both are real
#   - `''` is a REAL state of a REAL grove: a `--from src` push carries no
#     `.agent/`, so the manifest is absent and the org reads empty
#   - a name no arm carries is the future org, wired before its table lands
#   - ⇒ a fallthrough in either direction hands that box ahbode's reach
#
# 🛑 .the grade is the TARGET, never the ROW COUNT — and the two differ
#   - 📜 measured 2026-09-24, on this play's very first roll: an emptiness
#     probe ✋'d `5.12.rack/_rows` for its `<org>:camp` row. that row is the
#     box's OWN ambient badge, read off imds — it crosses no boundary at all,
#     and it is CORRECT for every org, declared table or no
#   - ⇒ the probe was the defect: it collapsed "no rows" with "no cross-org
#     rows", and reported a false ✋ against a bundle that was right
#   - (`gotcha.a-check-that-cries-wolf-gets-silenced`, the false-✋ half)
#
# ⚠️ the two READERS below still owe emptiness, and for a different reason:
#    each looks up ANOTHER repo's declaration — whose clones hold the role
#    names, which vendor keys the org mints. an undeclared org has no such
#    source, so an answer there is a fallthrough by construction
####################################################################
echo ""
for probe in '' 'org-that-no-arm-carries'; do
  say="${probe:-<empty>}"
  export GROVE_ORG="$probe"

  held=0

  # 3a. every row it IS handed must still target its own org
  for pair in $(grove_provision_5_13_reach_envs 2>/dev/null) ; do
    target="${pair%%:*}"
    _may_target "$probe" "$target" && continue
    echo "   ✋ org '${say}' was handed a 5.13.reach row into '${target}'"
    echo "      ⇒ a box whose org declares no table must never inherit"
    echo "        another org's reach — that is clause 3, exactly"
    fails=$((fails + 1)); held=1
  done

  for row in $(grove_provision_5_12_rack_awsprofile_rows 2>/dev/null) ; do
    target="${row%%:*}"
    _may_target "$probe" "$target" && continue
    echo "   ✋ org '${say}' was handed a 5.12.rack row into '${target}'"
    echo "      ⇒ the rack would name another org's profile on this box"
    fails=$((fails + 1)); held=1
  done

  # 3b. the two readers that reach into ANOTHER repo's declaration must refuse
  leaked=""
  [[ -n "$(grove_provision_5_13_reach_srcorg 2>/dev/null)" ]] && leaked="$leaked 5.13.reach/_srcorg"
  [[ -n "$(grove_provision_5_16_keys_required 2>/dev/null)" ]] && leaked="$leaked 5.16.keys/_required"

  if [[ -n "$leaked" ]]; then
    echo "   ✋ org '${say}' was handed a declaration source by:${leaked}"
    echo "      ⇒ an undeclared org has no clones that declare a role name and"
    echo "        no vendor key table, so an answer here is a fallthrough"
    echo "      ⇒ each owes a '*) return 0' arm, and a guard on an empty"
    echo "        GROVE_ORG before it reads"
    fails=$((fails + 1)); held=1
  fi

  [[ $held -eq 0 ]] && echo "   ✔ org '${say}' inherits no other org's reach"
done

if [[ -n "$_org_before" ]]; then export GROVE_ORG="$_org_before"; else unset GROVE_ORG; fi

####################################################################
# 4. the keyrack↔github alias ROUND-TRIPS, and its dir is REACHED
#
# 🛑 .why a round trip and not two spot checks
#   `grove_org_ghorg` and `grove_org_clonedir` read ONE table in opposite
#   directions, and five call sites lean on the pair. a table whose halves
#   disagree sends the clone to one dir and the read to another — and the
#   verify then reports every repo ABSENT on a converged box
#
# ⚠️ .the FORWARD half cannot be graded here, and this says so rather than
#    pretend: whether `aether → aether-auctions` names a github org github
#    actually has is a fact about GITHUB, not about this table
#   - 📜 measured 2026-09-24: `aether) printf 'aether'` listed an org github
#     does not have, `gh repo list` answered empty, and `5.10.repos` reported
#     `the token can see no repos here` — a TRUE verdict about an org nobody
#     owns. no offline reader can catch that; only a `gh repo list` can
#   - ⇒ so this grades the ALGEBRA (the two halves agree) and names the one
#     claim it does not reach, rather than imply a proof it has not made
#     (`rule.forbid.failhide`)
#
# 🛑 the DIR claim is what the five call sites actually need: every one joins
#      `~/git/<dir>/`, and each must get the SAME dir for one row
####################################################################
echo ""

for pair in $GROVE_ORG_GHORGS; do
  _org="${pair%%:*}"
  _gh="${pair#*:}"

  _fwd="$(grove_org_ghorg "$_org")"
  _bak="$(grove_org_clonedir "$_gh")"

  if [[ "$_fwd" != "$_gh" ]]; then
    echo "   ✋ alias $_org → $_gh: the forward read answered '$_fwd'"
    echo "      ⇒ the wire call would ask github for the wrong org"
    fails=$((fails + 1)); continue
  fi

  if [[ "$_bak" != "$_org" ]]; then
    echo "   ✋ alias $_org → $_gh: the reverse read answered '$_bak'"
    echo "      ⇒ the clone would land in ~/git/$_bak and every reader that"
    echo "        joins ~/git/$_org would report an absent tree"
    fails=$((fails + 1)); continue
  fi

  echo "   ✔ alias     $_org → $_gh (github), clones at ~/git/$_org"
done

# .an org NOT in the table must round-trip as itself, both ways
#   - the table lists only DIVERGENT pairs, so identity is the default and the
#     default is what nearly every org uses. a bug there breaks every org at once
for _org in ahbode ehmpathy whodisio; do
  if [[ "$(grove_org_ghorg "$_org")" != "$_org" || "$(grove_org_clonedir "$_org")" != "$_org" ]]; then
    echo "   ✋ org '$_org' is not in the alias table, so both reads must answer"
    echo "      '$_org' — one of them did not"
    fails=$((fails + 1))
  fi
done

# .an EMPTY arg returns empty, never `$HOME/git//` — a path-join with an empty
#  org collapses to a glob over EVERY org's clones, which is the 2026-09-24
#  defect re-entered through a join (see `5.13.reach/_account_declmap`)
if [[ -n "$(grove_org_ghorg '')" || -n "$(grove_org_clonedir '')" ]]; then
  echo "   ✋ an empty org must read empty from both halves"
  echo "      ⇒ an empty join spans every org's clones under ~/git/"
  fails=$((fails + 1))
else
  echo "   ✔ an empty org reads empty from both halves"
fi

echo ""
if [[ $fails -eq 0 ]]; then
  echo "🌲 prove.org-scoped-rows ✔"
  exit 0
fi
echo "🌲 prove.org-scoped-rows — $fails claim(s) did not hold ✋" >&2
exit 1
