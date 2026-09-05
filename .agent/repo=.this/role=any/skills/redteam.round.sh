#!/usr/bin/env bash
######################################################################
# .what = compose the dispatch prompt for an ingress-security round, with
#         every item that must ride along DERIVED from the tree rather than
#         retyped
#
# .why  = `howto.run-a-redteam-round.md` names six items a dispatch must carry,
#         and each was learned by its ABSENCE. a hand-typed prompt drops one
#         silently: the round still runs, still reports, and its report is
#         narrower than anybody can tell from reading it.
#
#         ⇒ so the six become a CONTRACT a command satisfies, never a checklist
#           a human recalls. the round is `rhx redteam.round --class N`.
#
# 🛑 .the item that made this a skill and not a checklist — the TOOL CAVEAT
#
#         item 4 is a claim about the TREE'S CURRENT STATE: a rename in flight
#         left ~207 files in the git INDEX and not on disk, so `rhx grepsafe`
#         and `globsafe` — both index-keyed — answered `0` for files plainly
#         there. an agent handed no caveat reports that `0` as a clean sweep.
#
#         written as prose it is wrong TWICE: it is wrong today if the drift
#         moved, and it is wrong forever once the rename lands — at which point
#         it warns about a hazard that has gone, and the next real drift arrives
#         with the warning already spent (m.13).
#
#         ⇒ this skill MEASURES the drift and emits the caveat only when there
#           is one, with today's count. a claim that re-derives cannot decay.
#
# ⚠️ .what this does NOT do
#         it emits TEXT. it dispatches no agent, edits no file, and reaches no
#         network. what a caller does with the prompt is the caller's move —
#         which keeps the composition auditable and re-runnable.
#
# ⚠️ .why `--class` is REQUIRED and never inferred
#         rounds 2-8 all swept ONE class and the yield decayed round on round.
#         a modulo over the round number would fabricate a rotation the history
#         does not have, and a wrong guess costs a whole round. so the choice is
#         the human's, and this refuses to guess it.
#
# ✔ .SEEN TO DISCRIMINATE, 2026-08-31 — four arms, and TWO defects it caught
#         · `--classes`          → the four rows, exit 0
#         · no `--class`         → ✋ refusal + the rows, exit 2
#         · `--class 9`          → ✋ names no class, exit 2
#         · `--class 4 --audit`  → the derived items, exit 0
#
#      🛑 both defects were in THIS FILE, found by its first two runs — which is
#         round 9's own lesson applied to the entooling of round 9's process:
#
#         1. item 5 reported **275** files. a rename was in flight, so the whole
#            moved subtree is uncommitted. a target list of 275 orders nothing,
#            so the freshest repair sits at random depth and reads as thorough
#         2. `--classes` printed a banner and NOT ONE ROW. it exits 0 and wrote
#            to stderr, and `rhx` relays a skill's stderr ONLY on a non-zero
#            exit. the REFUSAL arm was fine throughout — it exits 2 — which is
#            what makes the shape hard to see: the half that works is the half
#            you exercise while you write it
#
# usage:
#   rhx redteam.round --class 4              # compose the next round's dispatch
#   rhx redteam.round --class 2 --round 11   # name the round number too
#   rhx redteam.round --classes              # list the classes, and stop
#   rhx redteam.round --class 4 --audit      # only the DERIVED items, no prose
#
# exit:
#   0 = a dispatch was composed
#   2 = a caller error, or a source this prompt depends on could not be read
######################################################################
set -uo pipefail

CLASS=""
ROUND=""
AUDIT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --class)   CLASS="${2:-}"; shift 2 ;;
    --round)   ROUND="${2:-}"; shift 2 ;;
    --classes) CLASS="__list__"; shift ;;
    --audit)   AUDIT=1; shift ;;
    --help|-h)
      sed -n '/^# usage:/,/^#####/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//;$d'
      exit 0
      ;;
    # rhachet injects these into EVERY skill it runs. a skill that owns a flag
    # by one of these names silently takes rhachet's value (r7's twin defect)
    --repo|--role|--skill) shift 2 ;;
    *)
      echo "   ✋ unknown flag: $1" >&2
      echo "      valid: --class <n>  --round <n>  --classes  --audit  --help" >&2
      exit 2
      ;;
  esac
done

######################################################################
# the subject checkout is derived from THIS FILE, never from the cwd
#
# `rhx` guarantees no cwd, and a fallback that reads a DIFFERENT checkout does
# not fail — it silently answers about the wrong tree (dox.verify measured this,
# three subjects from three runs of one command)
######################################################################
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git -C "$SELF_DIR" rev-parse --show-toplevel 2>/dev/null || true)"

if [[ -z "$ROOT" ]]; then
  echo "   ✋ no git checkout above $SELF_DIR" >&2
  echo "      ⇒ every derived item below reads the tree, so a dispatch composed" >&2
  echo "        here would carry the prose and none of the measurements" >&2
  exit 2
fi

LEDGER="$ROOT/.temp/handoff.security.ingress-review.md"
HOWTO="$ROOT/.agent/repo=.this/role=any/briefs/creds/howto.run-a-redteam-round.md"

######################################################################
# the CLASSES. declared here because this is the only command that dispatches a
# round — a second copy in a brief would be one fact with two holders (m.9)
######################################################################
_class_name() {
  case "$1" in
    1) printf 'the transport — what crosses the wire, and which stream carries it' ;;
    2) printf 'the parse — what a value becomes when a local reader splits it' ;;
    3) printf 'the interpretation — what a local TOOL does with a file a grove wrote' ;;
    4) printf 'the checks themselves — a round whose subject is the prior rounds guards' ;;
    5) printf "the grove's own perimeter — how an attacker reaches a grove and runs code on it" ;;
    *) printf '' ;;
  esac
}

######################################################################
# 🛑 .CLASS 5 EXISTS BECAUSE THE LIST ITSELF ENCODED A BLIND SPOT
#
# 📜 measured 2026-09-02, after 21 rounds. classes 1-4 each take the LAPTOP as
#    their vantage — what crosses the wire TO it, what a LOCAL reader splits,
#    what a LOCAL tool interprets, and our own guards. so 21 rounds all asked
#    one question: can a compromised grove reach the laptop?
#
#    ⇒ and the answer every time was NO — 0 critical, 0 ingress. that record is
#      real, and it answers a question nobody should have asked alone.
#
# 🛑 the question the four classes CANNOT EXPRESS is the one that matters most:
#    HOW DOES A GROVE GET POPPED IN THE FIRST PLACE?
#
#    because a grove is not a worthless box. it holds:
#      · `@all.camp.GITHUB_TOKEN` — a classic pat, `repo` + `read:org`, and the
#        `@all` is deliberate: one pat spans EVERY org its human belongs to. one
#        popped grove reads and writes every private repo in all of them
#      · an aws instance role, reachable by ANY process on the box regardless of
#        unix user (`term=ground._.choice.reason.md`) — so the unprivileged
#        camper seat that runs the work has it too
#
#    ⚠️ `ASSUME COMPROMISED` is a POSTURE about what the LAPTOP should trust. it
#      was read, for 21 rounds, as though it also meant a grove compromise were
#      CHEAP. those are different claims and only the first one is true.
#
# ⇒ so a dispatch tool whose class list stops at four laptop-side classes can
#   never compose this round. the list was the defect, not the rounds
#   (`rule.require.solve-at-cause`).
######################################################################

# 🛑 the class SET is derived from `_class_name`, never re-typed
#
#    📜 it had THREE holders before class 5 was added: these case arms, a
#      `for n in 1 2 3 4` loop, and a `valid: 1 2 3 4` refusal string. two of
#      the three would have gone stale the moment a class was appended, and the
#      run would have READ a different list than it EXECUTED — the exact shape
#      that hid two subjects in `prove.tool-defaults-are-bounded`, and that
#      `prove.rack-consumers-are-dispositioned` hit again the same day.
_class_ids() {
  local n=1
  while [[ -n "$(_class_name "$n")" ]]; do
    printf '%s ' "$n"
    n=$(( n + 1 ))
    [[ "$n" -gt 99 ]] && break   # a bound, so a malformed case cannot spin
  done
}

######################################################################
# 🛑 .the LIST rides STDOUT, and the REFUSAL rides stderr — MEASURED
#
#    the first cut sent both to stderr, which reads as tidy and is a false ✔ in
#    one of the two arms:
#
#      `rhx` buffers a skill's stderr and relays it ONLY on a NON-ZERO exit.
#
#    so `--classes` — which exits 0 — printed the banner and NOT ONE ROW. the
#    refusal arm was fine (it exits 2, so its stderr arrived), which is what
#    makes this shape hard to see: the half that works is the half you test
#    while you write it.
#
#    ⇒ the split is by ROLE, not by tidiness. `--classes` is an ANSWER the
#      caller asked for → stdout. an absent `--class` is a REFUSAL → stderr,
#      with a non-zero exit to carry it.
######################################################################
######################################################################
# 🛑 .the RECENCY of a class is DERIVED, and it used to be TYPED
#
# 📜 measured 2026-09-03, redteam round 24 (F5). this block carried the line
#    `class 5 has NEVER been swept`, hardcoded on the day class 5 was added and
#    FALSE two days later — round 22 swept it, and so did round 24. i read my
#    own tool and relayed that sentence to a human as a fact about the repo.
#
#    ⇒ one fact, two holders (m.9). the LEDGER knows which class each round
#      swept, and this string claimed to know it too. the string is the copy
#      that no act of running a round can correct.
#
#    ⚠️ and it decays in the worst possible direction. a stale `never swept`
#      aims every future round at a class already worked twice — so the yield
#      is spent, and whichever class is genuinely cold stays unswept. the tool
#      whose whole job is to pick a target was misdirecting the pick.
#
# ⚠️ .the BOUND of this reader, stated because a count is a claim about a set
#    only headings of the shape `round N — YYYY-MM-DD, class M` carry a class,
#    and that shape starts at round 14. an earlier sweep is INVISIBLE here — so
#    an empty answer means **the ledger holds no record**, and it never means
#    `never swept` (q11: a row nobody can read produces no row)
######################################################################

######################################################################
# every round NUMBER the ledger HEADS — ascending, deduped
#
# 🛑 .HEADING-scoped, and that scope is load-bear
#    the first cut matched anywhere in the file, so PROSE counted. the moment
#    this ledger gained an entry that says *"no redteam round 21 is recorded"*,
#    that very sentence made 21 read as RECORDED — a round conjured by the
#    words that deny it. m.10's shape: a correction that re-creates the defect
#    it corrects. measured 2026-09-03, on the backfill written minutes earlier.
#
# ⚠️ ONE holder, two callers. the `--classes` list and the next-round
#    derivation were two copies of one grep, free to drift (m.9) — and one of
#    them decides the number an entire round is filed under
######################################################################
_ledger_rounds() {
  [[ -r "$LEDGER" ]] || return 0
  # ⚠️ reduce to the NUMBER before the dedupe. the ledger heads a round three
  #    ways — `redteam round 9`, `round 20`, `ROUND 3` — so a sort -u over the
  #    raw match lists one round up to three times and reads as more history
  #    than there is
  grep -iE '^#+ .*\bround [0-9]+' "$LEDGER" \
    | grep -oiE '\bround [0-9]+' \
    | grep -oE '[0-9]+' | sort -un
}

# every (round, class) pair the ledger heads, one `<round> <class>` per line
_ledger_pairs() {
  [[ -r "$LEDGER" ]] || return 0
  grep -oiE 'round [0-9]+ — [0-9]{4}-[0-9]{2}-[0-9]{2}, class [0-9]+' "$LEDGER" \
    | sed -E 's/^[Rr]ound ([0-9]+) — [0-9-]+, [Cc]lass ([0-9]+)$/\1 \2/'
}

# the HIGHEST round the ledger records against a class. empty = no record
_class_last_round() {
  _ledger_pairs | awk -v c="$1" '$2 == c { if ($1 + 0 > r + 0) r = $1 } END { if (r) print r }'
}

_emit_classes() {
  echo ""
  echo "🔭 the classes a round may sweep"
  for n in $(_class_ids); do
    printf '   %s. %s\n' "$n" "$(_class_name "$n")"
    local last; last="$(_class_last_round "$n")"
    if [[ -n "$last" ]]; then
      printf '      └─ last swept: round %s\n' "$last"
    else
      printf '      └─ last swept: no record — no ledger heading names this class\n'
    fi
  done
  echo ""
  echo "   ⚠️ rounds 2-8 all swept class 1 and the yield decayed each time."
  echo "      pick the class LEAST recently swept, and say so in the dispatch."
  echo "      ⇒ the rows above are read from the ledger on every run, so they"
  echo "        cannot go stale the way a typed claim here once did (F5)."
  echo ""
  echo "   ⚠️ 'no record' names this READER's reach, never the repo's history."
  echo "      only headings from round 14 on carry a class, so an older sweep"
  echo "      is invisible here. it is not a claim that the class is cold."
  echo ""
  if [[ -r "$LEDGER" ]]; then
    echo "   the ledger's recorded rounds:"
    _ledger_rounds | sed 's/^/      · round /'
  fi
}

if [[ "$CLASS" == "__list__" ]]; then
  _emit_classes            # an ANSWER — stdout, exit 0
  exit 0
fi

if [[ -z "$CLASS" ]]; then
  {                        # a REFUSAL — stderr, and exit 2 is what delivers it
    echo "   ✋ --class is required, and is never inferred"
    _emit_classes
  } >&2
  exit 2
fi

if [[ -z "$(_class_name "$CLASS")" ]]; then
  echo "   ✋ '$CLASS' names no class — valid: $(_class_ids)" >&2
  echo "      run: rhx redteam.round --classes" >&2
  exit 2
fi

######################################################################
# ITEM 6 (round number) — derived from the ledger, so it cannot double up
######################################################################
if [[ -z "$ROUND" ]]; then
  if [[ -r "$LEDGER" ]]; then
    LAST="$(_ledger_rounds | tail -1)"
    ROUND=$(( ${LAST:-0} + 1 ))
  else
    echo "   ✋ no ledger at $LEDGER, and no --round given" >&2
    echo "      ⇒ a round with no number cannot be recorded, and an unrecorded" >&2
    echo "        round's CLEAN list is lost to the round after it" >&2
    exit 2
  fi
fi

######################################################################
# ITEM 4 (the tool caveat) — 🛑 MEASURED, never asserted
#
# a reader whose SUBJECT comes from one store and whose CORPUS comes from
# another disagrees with itself the moment the two drift (q13). the index and
# the disk ARE two stores, and a rename puts them apart for hours at a time
######################################################################
INDEX_COUNT=0
ABSENT_COUNT=0
while IFS= read -r f; do
  INDEX_COUNT=$(( INDEX_COUNT + 1 ))
  [[ -e "$ROOT/$f" ]] || ABSENT_COUNT=$(( ABSENT_COUNT + 1 ))
done < <(git -C "$ROOT" ls-files 2>/dev/null)

######################################################################
# ITEM 5 (the prior round's repairs) — 🛑 derived from MTIME, not from memory
#
# .why  = "a REPAIR is the likeliest site of the next defect", and the freshest
#         repair is the one nobody points at. a hand-typed list names what the
#         author REMEMBERS editing, which is exactly the set their picture of
#         the subject already covers.
#
# 🛑 .why MTIME and not the uncommitted set — MEASURED on its first run
#         the first cut named every uncommitted code file. it reported **275**,
#         because a rename was in flight and the whole moved subtree is
#         uncommitted. a target list of 275 names no target at all: the reader
#         reads the first few and the freshest repair is buried at random depth.
#
#         ⇒ that is m.12's inverse, and it is the failure a dispatch can least
#           afford. a set too NARROW omits the defect; a set this WIDE hands the
#           reader no order, so the outcome is the same and it reads as thorough.
#
#         so the set is ORDERED by mtime and CAPPED. the cap is a presentation
#         bound, never a claim — the tally below says how many were cut, so a
#         reader is never told a truncated list is the whole one.
######################################################################
TOUCHED_CAP=20

# 🛑 .the PARSE — and why it is `cut -c4-` and not `awk '{ print $NF }'`
#
#    porcelain v1 emits a FIXED three-character prefix (`XY `) then the path, so
#    the path starts at column 4 and may hold spaces. `$NF` takes the last
#    WHITESPACE-delimited field, so `src/my file.sh` arrived as `file.sh` — which
#    then failed the `-f` test below and was dropped in silence.
#
#    ⚠️ measured 2026-09-02: `git ls-files -- '* *'` returns no rows in this tree,
#    so the defect was LATENT, never live. it is fixed anyway, because a target
#    list that drops a row silently is the one output nobody can audit — and the
#    file it would drop is a file somebody just touched, i.e. exactly item 5's
#    subject (`rule.forbid.failhide`).
#
#    a rename emits `R  old -> new`; the `sed` keeps the destination, which is
#    the file that now exists.
#
#    ⚠️ a path with a `"`, a `\`, or a newline is C-QUOTED by git and still
#    arrives mangled. `-c core.quotePath=false` does NOT turn that off — it only
#    stops the escape of non-ASCII. such a path fails the `-f` test and is
#    dropped, which is the safe direction; it is NOT claimed as handled.
TOUCHED_DISK="$(git -C "$ROOT" status --porcelain 2>/dev/null \
  | cut -c4- | sed 's/.* -> //' \
  | grep -E '\.(sh|lua|xml|json|conf|toml)$' | sort -u || true)"

# 🛑 .the two totals must describe the SAME set
#
#    this counted every porcelain row, and the list below can only ever hold rows
#    whose file is ON DISK — a rename leaves index rows with no file, and `stat`
#    on one prints an error and no row. with 207 such rows in this tree the
#    emitted "N further file(s) are NOT listed" overstated by the drift, so a
#    reader was told there were more readable files than there were.
#
#    ⇒ the `-f` filter now runs BEFORE the tally, so both numbers count one set.
TOUCHED_ALL=""
if [[ -n "$TOUCHED_DISK" ]]; then
  TOUCHED_ALL="$(while IFS= read -r f; do
      [[ -f "$ROOT/$f" ]] || continue
      printf '%s\n' "$f"
    done <<< "$TOUCHED_DISK")"
fi

TOUCHED_ALL_N=0
[[ -n "$TOUCHED_ALL" ]] && TOUCHED_ALL_N="$(printf '%s\n' "$TOUCHED_ALL" | wc -l | tr -d ' ')"

TOUCHED=""
if [[ -n "$TOUCHED_ALL" ]]; then
  TOUCHED="$(while IFS= read -r f; do
      printf '%s\t%s\n' "$(stat -c %Y "$ROOT/$f" 2>/dev/null || echo 0)" "$f"
    done <<< "$TOUCHED_ALL" | sort -rn | head -"$TOUCHED_CAP" | cut -f2-)"
fi

TOUCHED_N=0
[[ -n "$TOUCHED" ]] && TOUCHED_N="$(printf '%s\n' "$TOUCHED" | wc -l | tr -d ' ')"

######################################################################
# ITEM 3 (the CLEAN list) — read from the ledger, so it accumulates
######################################################################
CLEAN=""
if [[ -r "$LEDGER" ]]; then
  CLEAN="$(sed -n '/CLEAN list/,/^#\{1,4\} /p' "$LEDGER" \
    | grep -vE '^#|CLEAN list' | grep -vE '^\s*$' || true)"
fi

######################################################################
# the AUDIT view — the derived items alone, so a human can read WHAT WAS
# MEASURED without the prose that surrounds it
######################################################################
if [[ "$AUDIT" -eq 1 ]]; then
  echo "🔭 redteam.round --class $CLASS --round $ROUND"
  echo "   ├─ root:     $ROOT"
  echo "   ├─ class:    $(_class_name "$CLASS")"
  echo "   ├─ ledger:   $([[ -r "$LEDGER" ]] && echo 'readable' || echo 'ABSENT — items 3 and 5 degrade')"
  echo "   ├─ howto:    $([[ -r "$HOWTO" ]] && echo 'readable' || echo 'ABSENT — the process is unstated')"
  echo "   ├─ index:    $INDEX_COUNT tracked, $ABSENT_COUNT absent from disk"
  echo "   ├─ touched:  $TOUCHED_N of $TOUCHED_ALL_N uncommitted code file(s), newest first — item 5"
  echo "   └─ clean:    $([[ -n "$CLEAN" ]] && echo 'carried from the ledger' || echo 'EMPTY — the round re-walks settled ground')"
  exit 0
fi

######################################################################
# the DISPATCH
######################################################################
cat <<PROMPT
You are a red-team security reviewer for \`github.com/uladkasach/dev-env-setup\` — a
**PUBLIC** repo that provisions its owner's laptop and disposable cloud "grove" boxes.
Working dir: $ROOT

This is **defensive security review of the owner's own repo**, authorized and ongoing.
This is round $ROUND of a standing cycle. FIND defects and report them — edit no file.

FIRST read these two, in order. They are nine rounds of accumulated process and will
save you most of your budget:
1. \`.agent/repo=.this/role=any/briefs/creds/howto.run-a-redteam-round.md\`
2. \`.agent/repo=.this/role=any/briefs/evidence/gotcha.a-check-that-cries-wolf-gets-silenced.md\`
   — thirteen questions; q1, q7, q8, q11, q13 are the ones you will use most

## 1. the trust gradient

\`open internet < a grove (ASSUME COMPROMISED) < the laptop (holds the rack)\`

🛑 **\`ASSUME COMPROMISED\` names a POSTURE, never a cheap outcome.** it says what the
LAPTOP must not trust. it does NOT say a popped grove is worth little — and for 21
rounds it was read as though it did. a grove holds, right now:

- **\`@all.camp.GITHUB_TOKEN\`** — a classic pat, \`repo\` + \`read:org\`. the \`@all\` is
  deliberate: one pat spans EVERY org its human belongs to. one popped grove reads and
  writes every private repo in all of them.
- **an aws instance role** into the camp account, reachable by ANY process on the box
  regardless of unix user — so the unprivileged camper seat that runs the work has it.

⇒ so the ordering above is about **what may be trusted**, not about what may be lost.
grade a grove-only impact as real, and say which of the two assets it reaches.

## 2. the influence categories

An **ingress vuln** is remote-chosen bytes gaining influence on a more-trusted side as
any of: CODE, a PATH/FILENAME, a TRUST ANCHOR, an ENV VAR, a TERMINAL ESCAPE, or a
WRITE DESTINATION.

## 3. THE CLASS FOR THIS ROUND — $CLASS

> $(_class_name "$CLASS")

Sweep this class. The governing heuristic, proven over nine rounds:

> **THE GUARD IS RARELY ABSENT. IT IS WEAKER THAN ITS OWN CLAIM.**

So on ground a prior round already walked, your question is not *"what is unguarded?"* — it is:

> **for each guard, what exactly does its comment CLAIM, and what does its code REACH?**

🛑 **BUT THAT HEURISTIC ASSUMES SWEPT GROUND, AND IT INVERTS ON A FIRST SWEEP.**

it was learned across 21 rounds aimed at surfaces somebody had already reviewed. there,
a guard was nearly always present and merely weaker than its comment. **on a class no
round has ever swept, absence is a live hypothesis and often the answer** — nobody has
looked, so no pressure ever forced a guard to exist.

⇒ so on a first sweep you owe BOTH passes, and the enumeration comes FIRST:

1. **ENUMERATE THE ENTRYPOINTS.** build the list of every way remote-chosen bytes
   reach this subject at all — every listener, every fetch, every file read, every
   value accepted from outside. derive it from the tree; do not accept any list
   somebody typed, including this one. **an entrypoint nobody enumerated has no
   guard to be weaker than its claim, and no round can report what it never listed.**
2. **THEN** ask the claim-vs-reach question of whatever guards that list turned up.

⚠️ report the entrypoint list itself, even where every entry is guarded. it is the
round's most durable output: the next round inherits the set instead of a re-derivation
of it, and a set no one wrote down is one no one can notice a new member of.

## 4. ⚠️ TOOL CAVEAT — measured against this tree, just now
PROMPT

if [[ "$ABSENT_COUNT" -gt 0 ]]; then
  cat <<PROMPT

🛑 **$ABSENT_COUNT of $INDEX_COUNT tracked files exist in the git INDEX and NOT on disk.**

\`rhx grepsafe\` and \`rhx globsafe\` are **INDEX-keyed**. A \`0\` from either is **NOT
evidence of absence** — this is q13, two stores and one reader. **Use the native
Grep / Glob / Read tools.** If you report "no matches", name the tool that produced it.
PROMPT
else
  cat <<PROMPT

✔ the index and the disk AGREE ($INDEX_COUNT tracked files, 0 absent), so \`rhx grepsafe\`
and \`globsafe\` are sound this round. Still name the tool behind any "no matches" claim.
PROMPT
fi

cat <<PROMPT

## 5. NAMED TARGETS — the freshest repairs

A repair is the likeliest site of the next defect: a check written by the author of a
fix, in the same hour, inherits that author's picture of what the subject looks like.
A fixture proves obedience; only a subject the author did not write proves reach.

These are the $TOUCHED_N most recently modified of $TOUCHED_ALL_N uncommitted code files,
**newest first** — so the top of this list is the freshest repair in the tree.
Read them adversarially, in this order:

PROMPT

if [[ -n "$TOUCHED" ]]; then
  printf '%s\n' "$TOUCHED" | sed 's/^/- `/;s/$/`/'
  if [[ "$TOUCHED_ALL_N" -gt "$TOUCHED_N" ]]; then
    echo ""
    echo "⚠️ $(( TOUCHED_ALL_N - TOUCHED_N )) further uncommitted code file(s) are NOT listed."
    echo "   The cut is by mtime alone, so it is a bound on this page and not a claim about"
    echo "   the tree. If your class points at one of them, read it — it is in scope."
  fi
else
  echo "_(the working tree is clean — no fresh repair to target; say so in your report)_"
fi

cat <<PROMPT

## 6. CLEAN — walked and sound in prior rounds. Do NOT re-walk.

PROMPT

if [[ -n "$CLEAN" ]]; then
  printf '%s\n' "$CLEAN"
else
  cat <<'PROMPT'
⚠️ no CLEAN list could be read from the ledger. Budget for that: you may re-walk
ground a prior round already settled. Say so in your report so the next round is told.
PROMPT
fi

cat <<'PROMPT'

## 7. what a defect you report must carry

🛑 **SEVERITY AND DISPOSITION ARE TWO COLUMNS, NEVER ONE.** rounds 2-14 reported one
word, `BLOCKER`, which grades MERGE-READINESS and reads to a human as CVSS-CRITICAL.
after round 14 the human pushed back three times — *"what are actual blockers though.
i.e., critical severity vulnerabilities"*, *"none of these increase our security risk
above what we had"*, *"nor do any of them seem like they would enable someone to
exploit our habitats"* — and was right every time. re-graded honestly, round 14 held
**zero critical and zero ingress vectors**, while its own report said "2 blockers".

⚠️ that is `gotcha.a-check-that-cries-wolf-gets-silenced` aimed at YOU. a grader that
over-reports gets discounted, and then the one round that IS critical reads like the
fourteen before it. **so grade DOWN by default and let the vector argue you up.**

so each row carries BOTH:

| column | the question | values |
|---|---|---|
| **severity** | how bad is it, on its own? | CRITICAL / HIGH / MEDIUM / LOW / NOT-A-VULN |
| **disposition** | what should happen to the merge? | blocker / nitpick / accepted-risk |

they are free to disagree, and usually do: a broken clamp is `NOT-A-VULN` severity and
a `blocker` disposition. a documented, human-owned config is `HIGH` severity and
`accepted-risk`.

**a severity with no argument is an opinion.** so beside the grade, state:

- **ingress or escalation?** — does this let somebody IN, or only let somebody ALREADY
  in reach further? say it in those words. it is the first thing the human asks.
- **the preconditions, counted** — every condition that must hold at once. a chain of
  four is not the same defect as a chain of one, and the grade must show it.
- **which side takes the impact** — the grove alone, or the laptop. a defect that
  CROSSES to the laptop outranks one that does not.
  ⚠️ but "grove only" is NOT "cheap" — see §1. a grove holds an org-wide github pat and
  an aws instance role, so name WHICH of the two a grove-only defect reaches, and grade
  that reach. a compromise that hands over every private repo in two orgs is HIGH even
  though it never touched the laptop.
- **additive?** — a change that only ADDS or TIGHTENS a guard cannot raise risk above
  the prior state. say so, and do not gate a merge on it.

🛑 **`CRITICAL` has TWO arms, and a defect needs only ONE of them.**

1. **remote-chosen bytes reach the LAPTOP as CODE**, with no already-compromised
   precondition. if you must first assume a grove is owned, that arm is at most
   `MEDIUM` and it is ESCALATION, not ingress.
2. **the OPEN INTERNET runs code on a GROVE**, with no already-compromised
   precondition — because a grove is not an empty box. it holds an org-wide github
   pat and an aws instance role (§1), so unauthenticated code execution there hands
   over every private repo in two orgs. that is INGRESS, and it is CRITICAL even
   though the laptop was never touched.

⚠️ **arm 2 exists because arm 1 alone caps a round below its own subject.** for 21
rounds the laptop was the only more-trusted side anyone graded against, so a defect
that stopped at the grove could never score above `MEDIUM` however far it reached.
that is the severity half of the very blind spot class 5 was added to close.

if the guarded fact was correct on the day it was written and only a drift-reader was
absent, it is `NOT-A-VULN` — however much real work the repair is.

- **file:line**
- **the CLAIM** its own comment/row makes, quoted
- **what the code REACHES**, and the concrete input that falls in the gap
- **the fix at cause** — and run these three on it BEFORE you write it:
  1. is there a site this pattern matches where the correct value is DIFFERENT? (q7)
  2. what did the reader hand this pattern, and is that still what the file says? (q8)
  3. does my fix hold in EVERY context this code runs in? (a `trap … EXIT` is right in
     an executable and a regression in a function sourced into a human's shell)

## 8. ⚠️ A REFUTATION IS A DELIVERABLE, NOT A FAILURE

> **a false ✋ that names a plausible fix is the most damaging output a redteam can
> produce, because the fix gets applied and IS a regression.**

If you check something and it is sound, say so — that goes on the CLEAN list and saves
the next round. If you cannot verify a claim from this repo alone, say that in those
words rather than assert it.

## 9. output

End with the reviewer contract — two numeric lines:

```
N blockers
N nitpicks
```

Then a CLEAN list of what you walked and found sound.

Read files. Run read-only commands. Edit no file.
PROMPT
