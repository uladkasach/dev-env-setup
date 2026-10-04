#!/usr/bin/env bash
######################################################################
# .what = the ONE org this grove belongs to, derived once per run
#
# .why  = `rule.require.a-grove-reaches-its-own-org-only`
#   - a grove reaches its OWN org. every cross-org reach is an opt-in row
#   - so every table that names an account, a role, a rack slug, or a vendor
#     key must be keyed on THIS fact, and on no other
#   - 🔴 an org with no declared table gets ZERO rows. it does NOT fall back
#     to some other org's table
#
# 📜 .the measurement that bought this file — 2026-09-24
#   an AETHER grove refused five `sts:AssumeRole` calls into ahbode and
#   ehmpathy accounts. five tables across three bundles held `ahbode` as a
#   hardcoded scalar and no org axis at all, so the box inherited ahbode's
#   whole reach table by construction and every refusal was aws correct.
#
#   an infra ask was drafted to have those hops GRANTED — which would have
#   bought an aether box a permanent assume-role into ahbode prod, to silence
#   a check that was right. the wisher stopped it.
#
#   ⇒ a defect whose symptom is AccessDenied has a repair that READS as
#     "grant it". that is the trap, and this file is the fix at cause.
#
# .note = it is a RUN fact, beside `GROVE_MODE`, never a MACHINE fact beside
#         `GROVE_ENV_SERVER`. the same disk can be provisioned for a different
#         org by a different checkout, and the box's hardware says no word
#         about whose work it does
######################################################################

######################################################################
# .what = read the `org:` a checkout DECLARES, out of its root keyrack manifest
#
# 🛑 .why the manifest and not a probe of the box
#   - the manifest is what EVERY keyrack call in this repo already resolves
#     against, so a second source would be a second answer to one question and
#     the two would drift (`rule.require.identical-bundle-composition`)
#   - a probe of the box — its instance role's arn, its hostname, its clone
#     set — answers "whose account is this?" and NOT "whose work does this box
#     do". the two agree today and are different questions
#   - ⚠️ an inference from a repo name or from the table that happens to be
#     there is the exact blocker the rule above names
#
# 🛑 anchored at column 0 on `org:`, so a mention inside a comment cannot
#      answer. that manifest carries a long comment block about this very line
#
# .note = an ABSENT manifest returns empty and exits 0. a checkout pushed with
#         `--from src` carries no `.agent/` at all, so absence is a normal
#         state of a legitimate box — and clause 3 makes it SAFE: no org, no
#         rows. the callers say so loudly; this reader does not fail
######################################################################
grove_org_declared() {
  local root manifest
  root="$(dirname "${GROVE_SRC:-}")"
  manifest="$root/.agent/keyrack.yml"

  [[ -f "$manifest" ]] || return 0

  grep -m1 -E '^org:[[:space:]]*[^[:space:]]' "$manifest" \
    | sed -E 's/^org:[[:space:]]*//; s/[[:space:]]+$//'
}

######################################################################
# .what = settle this run's org, from the flag or the manifest, and EXPORT it
#
# .why  exported = several bundles at several tree depths key their tables on
#       it, and a subshell must read the same answer. two derivations of one
#       fact is this repo's oldest defect
#
# .why a FLAG at all, when the manifest already declares it
#   - the manifest is a property of the CHECKOUT, and one checkout is pushed
#     to a grove per org. so the default is right nearly always
#   - the flag is what lets a human PLAN another org's view from this laptop
#     (`rhx grove.provision --org aether --mode plan`) without a swap of the
#     manifest line — the same service `--for cloud` gives for a box class
#
# 🛑 .no prompt, ever. the org arrives as a FLAG or as a DECLARATION, and
#      never from a tty — `rule.require.one-command-provision`'s
#      non-interactive clause, which a preflight question would break outright
######################################################################
grove_org_derive() {
  local given="${1:-}"

  if [[ -n "$given" ]]; then
    export GROVE_ORG="$given"
    export GROVE_ORG_FROM="flag"
    return 0
  fi

  export GROVE_ORG="$(grove_org_declared)"
  export GROVE_ORG_FROM="manifest"
}

######################################################################
# .what = the fix-text an empty `GROVE_ORG` earns, for a caller that needs one
#
# .why  ONE holder = three bundles decline for this same cause, and a decline
#       that names the wrong file is the defect
#       (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
######################################################################
######################################################################
# .what = list the orgs a per-org table declares an arm for
#
# .why  = a clamp over a per-org table must walk EVERY org, and the ambient
#         `GROVE_ORG` names at most one. a play that asks the table with an
#         unset org gets ZERO rows back and reports a clean pass
#   - 📜 measured 2026-09-24, minutes after the per-org split landed:
#     `prove.reach-envs-are-declared` printed not one row and exited 0 ✔.
#     the clamp was correct, unchanged, and blind — its subject had grown an
#     axis it did not walk
#   - ⇒ `gotcha.a-check-that-cries-wolf-gets-silenced`, q11: a count is only
#     as big as the reader's reach, and a table it cannot open reports none
#
# 🛑 .why it is DERIVED off the arms, never a list typed into a play
#   - a typed list is a second holder of the table's own fact, and it goes
#     stale in silence the day a third org lands (m.9)
#   - ⇒ the arms ARE the declaration, so the arms are what it reads
#
# ⚠️ its SILENCE is two facts — an absent arm set, and a parse that missed.
#    so a caller must treat an empty read as `exit 2`, never as a pass. this
#    reader cannot part them, and it does not pretend to
#
# .note = `*)` is excluded by the charset: it is the safe default, not an org
######################################################################
grove_org_tabled() {
  local file="${1:-}" fn="${2:-}"
  [[ -n "$file" && -f "$file" && -n "$fn" ]] || return 1

  sed -n "/^${fn}() {/,/^}/p" "$file" \
    | grep -oE '^[[:space:]]+[a-z][a-z0-9|._-]*\)' \
    | sed -E 's/^[[:space:]]+//; s/\)$//' \
    | tr '|' '\n'
}

######################################################################
# .what = every keyrack↔github org pair whose two NAMES DIVERGE, as
#         `<org>:<ghorg>`. an org absent from this list is identity
#
# 🛑 .why a table at all — the two are DIFFERENT NAMESPACES
#   - `GROVE_ORG` is the org the keyrack resolves against
#   - a github org is a name github holds, and the two are free to disagree
#   - ⇒ so every per-org table whose VALUE is a github name is a MAP, and a
#     reader that assumes the key spells the value has made a guess
#
# 📜 .the measurement — 2026-09-24
#   `aether` is the keyrack org; `aether-auctions` is the github org. an arm
#   written as `aether) printf 'aether'` listed an org github does not have,
#   `gh repo list` answered with an empty set, and `5.10.repos` reported
#   `the token can see no repos here` — a TRUE verdict, about an org nobody
#   owns. the wrong value did not error; it produced an honest-looking report
#   about a subject that does not exist, and a reader would have chased the
#   token's scope (`rule.require.trust-but-verify`)
#
# 🛑 .it names an org's OWN github org, never its opt-ins
#   `5.10.repos`'s clone set lists opt-ins beside own-org, so that table cannot
#   be inverted to answer this. ownership is its own fact and gets its own row
#
# ⚠️ .ONE holder, read BOTH directions
#   the pair is asked forward (`_ghorg`) and backward (`_clonedir`). two
#   separate tables would be one fact with two holders, free to drift the day a
#   second org diverges (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
######################################################################
GROVE_ORG_GHORGS='aether:aether-auctions'

# .what = the GITHUB org a keyrack org owns. identity where the two agree
grove_org_ghorg() {
  local org="${1:-}" pair
  [[ -n "$org" ]] || return 0

  for pair in $GROVE_ORG_GHORGS; do
    [[ "${pair%%:*}" == "$org" ]] && { printf '%s' "${pair#*:}"; return 0; }
  done

  printf '%s' "$org"
}

######################################################################
# .what = the dir under `~/git` that a github org's clones live in
#
# 🛑 .THE DISK IS KEYED ON THE KEYRACK ORG, and never on github's name
#   - every other table in this repo keys on `GROVE_ORG`: the reach rows, the
#     rack slugs, the vendor keys, the acceptance target
#   - so a disk laid out by GITHUB's names is the one surface where a human
#     (and three readers below) must hold a second namespace in their head
#   - ⇒ `aether-auctions/svc-x` clones to `~/git/aether/svc-x`, and the github
#     name is confined to the ONE call that needs it — `gh repo list|clone`
#
# ⚠️ .so the alias REDUCES the namespace split rather than adds one
#   the divergence is github's, and it is real; this decides where it STOPS.
#   it stops at the wire
#
# 🛑 .every `~/git/<org>/` join asks THIS reader — there are five
#   `5.10.repos` clones into it (upsert), reads it back (verify), `5.13.reach`
#   joins it three ways (`_rolesrc`, `_arnsrc`, `_srcrepo`) plus a glob, and
#   `git.grove.provision test` derives its tree from it. a join that spells the
#   github name reaches for a dir the clone never made (m.9)
#
# ⚠️ .the hazard it accepts, stated rather than hidden
#   the dir no longer spells the github org, so `basename $(dirname .)` is NOT
#   the github org for an aliased row. read the CLONE's own remote for that —
#   `git -C <dir> remote get-url origin` — never the path it sits at
######################################################################
grove_org_clonedir() {
  local ghorg="${1:-}" pair
  [[ -n "$ghorg" ]] || return 0

  for pair in $GROVE_ORG_GHORGS; do
    [[ "${pair#*:}" == "$ghorg" ]] && { printf '%s' "${pair%%:*}"; return 0; }
  done

  printf '%s' "$ghorg"
}

grove_org_absent_say() {
  echo "     ⇒ this run has no org, so no row is owed — an org with no declared"
  echo "       table gets ZERO rows, never another org's"
  echo "       (rule.require.a-grove-reaches-its-own-org-only)"
  echo "     fix: name it on the command —"
  echo "       rhx grove.provision --org <org> --mode apply"
  echo "     or: declare it in this checkout's .agent/keyrack.yml, as 'org: <org>'"
}
