#!/usr/bin/env bash
######################################################################
# .what = every SKILL a tracked file depends on is itself TRACKED
#
# the peer of `prove.declared-assets-are-tracked`. that one asks whether
# the files a bundle COPIES ship; this asks whether the files a skill CALLS
# ship. same two stores, same silence, a different subject.
#
# .why
#   - a tracked skill that `source`s an untracked peer dies at that line
#     on every box but the one that authored it
#   - a tracked fix-text that names an untracked skill hands a human a
#     command that answers "no such skill" wherever it is read
#   - neither failure is visible here: the author's disk holds both files
#
# 🛑 .THE CLASS THIS CLAMPS — measured 2026-09-29
#
#    the org axis moved six skills' rack reads into ONE holder,
#    `git.grove.rack.operations.sh`, and that holder was never staged:
#
#    | the dependent                         | how it depends        |
#    |---------------------------------------|-----------------------|
#    | 8 tracked skills                      | `source` it directly  |
#    | `git.grove.ready.verify.sh:354`       | a fix-text names its  |
#    |                                       | peer, `…rack.unlock`  |
#
#   - all 8 run clean HERE and abort at their `source` line on a fresh clone
#   - `prove.rack-consumers-are-dispositioned` could not see the holder at
#     all: its walk was `git grep`, which reads the INDEX
#   - ⇒ so the six rows that described those reads read STALE, while the
#     reads themselves sat one unstaged file away, unreachable and unjudged
#
# ⚠️ .why ARM 2 does NOT strip comments, where every peer reader does
#   - m.8 says strip prose, because a documented call is not a live call
#   - that holds for a call a MACHINE makes. it inverts for one a HUMAN runs:
#     a fix-text is READ ALOUD to a human and then typed, so the dependency
#     is real precisely because it sits in prose
#   - ⇒ arm 1 strips comments; arm 2 must not. one reader, two rules, and the
#     discriminator is WHO executes the line
#
# ⚠️ .residue, stated rather than papered over
#
#   1. arm 2 judges only a slug that resolves to a file under this repo's OWN
#      skills dir. `rhx grepsafe` names a mechanic skill from another package,
#      which this checkout neither holds nor ships — unresolvable, so unjudged
#      and COUNTED as such (`rule.forbid.failhide`)
#
#   2. this play asks PRESENCE, never CURRENCY — the same bound its peer
#      declares. a ✔ means "it ships", never "the edit ships"
#
# usage:
#   rhx play.run --play prove.declared-skills-are-tracked
######################################################################
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$ROOT" ]]; then
  echo "✋ no git checkout here, so the INDEX cannot be asked" >&2
  echo "   ⇒ half this play's subject is unreachable; it proves no claim" >&2
  exit 2
fi
cd "$ROOT" || exit 2

SKILLS_REL=".agent/repo=.this/role=any/skills"

echo "🌲 prove.declared-skills-are-tracked"
echo "   └─ subject: every skill a TRACKED file depends on"
echo ""

######################################################################
# 1. THE EXTRACTORS — proven on fixtures before they read a real file
######################################################################

# arm 1: a `source`d peer. COMMENTS STRIPPED — a machine runs this line
_arm1_targets() {
  sed 's/#.*$//' \
    | grep -E '^[[:space:]]*(source|\.)[[:space:]]' \
    | grep -oE '[A-Za-z0-9._-]+\.sh' \
    | sort -u
}

# arm 2: an `rhx <slug>`. COMMENTS KEPT — a human runs this line
_arm2_slugs() {
  grep -oE '\brhx[[:space:]]+[a-z0-9][a-z0-9._-]*' \
    | sed 's/^rhx[[:space:]]*//' \
    | sort -u
}

FIX_A1_LIVE='source "$(dirname "${BASH_SOURCE[0]}")/git.grove.rack.operations.sh"'
FIX_A1_NOTE='#   source "$(dirname "$0")/never.sh"   — a note, not a call'
FIX_A2_TEXT='  echo "      fix: rhx git.grove.rack.unlock --env camp" >&2'

SELFTEST=0
[[ "$(printf '%s\n' "$FIX_A1_LIVE" | _arm1_targets)" == "git.grove.rack.operations.sh" ]] \
  || SELFTEST=$((SELFTEST + 1))
[[ -z "$(printf '%s\n' "$FIX_A1_NOTE" | _arm1_targets)" ]] \
  || SELFTEST=$((SELFTEST + 1))
[[ "$(printf '%s\n' "$FIX_A2_TEXT" | _arm2_slugs)" == "git.grove.rack.unlock" ]] \
  || SELFTEST=$((SELFTEST + 1))

if [[ "$SELFTEST" -gt 0 ]]; then
  echo "   └─ 💥 an extractor fails its own fixtures ($SELFTEST of 3)" >&2
  echo "      · it cannot tell a dependency from prose about one" >&2
  echo "      · every verdict below would be unfounded, so none is offered" >&2
  exit 2
fi
echo "   ├─ extractors: ✔ discriminate (3/3 fixtures)"

######################################################################
# 2. the SUBJECT — every TRACKED file, since only a tracked file ships
######################################################################
mapfile -t TRACKED_SH < <(git ls-files -- '*.sh' | sort -u)
mapfile -t TRACKED_ALL < <(git ls-files -- '*.sh' '*.md' | sort -u)

if [[ "${#TRACKED_SH[@]}" -eq 0 ]]; then
  echo "   └─ 💥 no tracked shell file reached — an empty subject" >&2
  echo "      · a clean page about a set nobody reached is not a proof (m.12)" >&2
  exit 2
fi
echo "   ├─ tracked shell files: ${#TRACKED_SH[@]}"
echo "   ├─ tracked files, both arms: ${#TRACKED_ALL[@]}"

_is_tracked() { git ls-files --error-unmatch -- "$1" >/dev/null 2>&1; }

echo ""

######################################################################
# 3. ARM 1 — a tracked skill sources an untracked peer
######################################################################
FAIL=0
ARM1_SEEN=0

for f in "${TRACKED_SH[@]}"; do
  [[ -f "$f" ]] || continue
  dir="$(dirname "$f")"
  while IFS= read -r t; do
    [[ -n "$t" ]] || continue
    target="$dir/$t"
    [[ -f "$target" ]] || continue          # not a peer of this file
    ARM1_SEEN=$((ARM1_SEEN + 1))
    _is_tracked "$target" && continue
    echo "   ✋ SOURCED, UNTRACKED — $target"
    echo "      · sourced by $f, which IS tracked"
    echo "      · so a push carries the caller and not the callee: every"
    echo "        box but this one aborts at that source line"
    echo "      · the index is a human's to write; hand them this path"
    FAIL=$((FAIL + 1))
  done < <(_arm1_targets < "$f")
done
echo "   ├─ arm 1 — peer sources resolved: $ARM1_SEEN"

######################################################################
# 4. ARM 2 — a tracked file names an untracked skill of THIS repo
######################################################################
ARM2_SEEN=0
ARM2_FOREIGN=0
declare -A ARM2_SAID=()

for f in "${TRACKED_ALL[@]}"; do
  [[ -f "$f" ]] || continue
  while IFS= read -r slug; do
    [[ -n "$slug" ]] || continue
    target="$SKILLS_REL/$slug.sh"
    if [[ ! -f "$target" ]]; then
      ARM2_FOREIGN=$((ARM2_FOREIGN + 1))   # another role's skill — unjudged
      continue
    fi
    ARM2_SEEN=$((ARM2_SEEN + 1))
    _is_tracked "$target" && continue
    [[ -n "${ARM2_SAID[$target]:-}" ]] && continue
    ARM2_SAID[$target]=1
    echo "   ✋ NAMED, UNTRACKED — $target"
    echo "      · named as 'rhx $slug' from $f, which IS tracked"
    echo "      · so the line reads as runnable and resolves to no skill"
    echo "        wherever this repo is read but this disk"
    echo "      · the index is a human's to write; hand them this path"
    FAIL=$((FAIL + 1))
  done < <(_arm2_slugs < "$f")
done
echo "   ├─ arm 2 — local skills named: $ARM2_SEEN"
echo "   ├─ arm 2 — foreign slugs, unjudged: $ARM2_FOREIGN (declared residue 1)"

echo ""
if [[ "$FAIL" -gt 0 ]]; then
  echo "└─ ✋ $FAIL dependency(ies) do not ship" >&2
  exit 1
fi
echo "✨ every skill a tracked file depends on is tracked too"
