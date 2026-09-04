#!/usr/bin/env bash
######################################################################
# .what = every ASSET a bundle phase names through `$GROVE_SRC` is TRACKED
#
# .why
#   - a bundle copies a file from the checkout onto the box
#   - a file git does not track exists on the author's disk and SHIPS TO NOBODY
#   - a fresh clone converges a box that silently lacks it
#
# 🛑 .THE CLASS THIS CLAMPS — measured THREE times on 2026-09-02 alone
#
#    | what was untracked                    | what it cost                    |
#    |---------------------------------------|---------------------------------|
#    | `grove.bootstrap.sh` + 4 `src/grove.*` | the published repo cannot boot  |
#    | 9 `.play/permanent/*` + its runner     | every clamp reached one box     |
#    | `src/lazy-lock.json`                   | SC-F1's plugin pins, reverted   |
#
#   - the third is the sharpest, the reason this play is `prove.*` rather than a note
#   - `4.5.nvim/configure.upsert.sh` copies the lockfile to `~/.config/nvim/`; `configure.verify.sh` `cmp`s it — a fully-owned asset, both phases correct
#   - untracked, a fresh clone has no lockfile: the upsert prints its ✋, every nvim plugin then lands on HEAD — unpinned remote lua, in the editor that opens every file on the box
#   - ⇒ a FIX CAN SHIP NOWHERE, indistinguishable from a fix that shipped: the pin was written, reviewed, cited — just never added
#
# ⚠️ .why no reader caught it, and why THIS reader can
#   - every gate here walked the DISK (`find`); an untracked file reads exactly like a tracked one
#   - the two stores disagreed and no reader asked the second one (`gotcha.a-check-that-cries-wolf-gets-silenced`, q13)
#   - ⇒ this play asks BOTH: the bundle tree for the asset set, the INDEX for whether each ships — neither store alone answers
#
# 🛑 .the SET IS DERIVED, never typed
#   - a hand-written asset list cannot report the member nobody added (`rule.require.one-command-provision`) — this defect exactly, one level up
#   - the subjects come out of `src/grove.provision/**` itself
#
# ⚠️ .residue, stated rather than papered over — TWO of them
#
#   1. a reference built at RUNTIME — `$GROVE_SRC/machine/$name` — names no path a grep can expand
#      - it is COUNTED and REPORTED, never silently dropped (`rule.forbid.failhide`)
#
#   2. 🛑 this play asks PRESENCE, never CURRENCY
#      - `git ls-files --error-unmatch` answers *is this path in the index*, not *does the index hold what the author just wrote*
#      - a `git add` run before a fix and never re-run leaves a path marked ✔ whose committed copy is the PRE-FIX version
#      - 📜 2026-09-02, minutes after round 20's blockers closed: 127 tracked files held an index copy that differed from disk, FIVE of them those very repairs — 487 insertions a plain `git commit` would have left behind, each one scored ✔ here
#      - ⇒ a ✔ here means "it ships", never "the fix ships" — the currency half has no reader (`howto.run-a-redteam-round`, .the SECOND half)
#
# usage:
#   rhx play.run --play prove.declared-assets-are-tracked
#   rhx git.grove.send <grove> --play prove.declared-assets-are-tracked
######################################################################
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$ROOT" ]]; then
  echo "✋ no git checkout here, so the INDEX cannot be asked" >&2
  echo "   ⇒ half this play's subject is unreachable; it proves no claim" >&2
  exit 2
fi

BUNDLES="$ROOT/src/grove.provision"
if [[ ! -d "$BUNDLES" ]]; then
  echo "✋ no bundle tree at $BUNDLES" >&2
  echo "   ⇒ the subject would be empty, and a tally of 0 reads as a pass" >&2
  exit 2
fi

echo "🌲 prove.declared-assets-are-tracked"
echo "   └─ root: $ROOT"
echo ""

######################################################################
# .what = every literal `$GROVE_SRC/<path>` a bundle names, expanded
#
# ⚠️ COMMENTS AND FIX-TEXT ARE STRIPPED FIRST — m.8
#   - nine phases explain an asset in a `#` block or echo its path in a fix-text
#   - a naive grep reads those as declarations
#   - that re-authors the reader's own subject and gives it a second place to be wrong
######################################################################
declare -a LITERAL=() DYNAMIC=()

collect() {
  local file line rest expanded
  while IFS= read -r file; do
    while IFS= read -r line; do
      # a dynamic tail (`$GROVE_SRC/machine/$name`) is caught FIRST, before the
      # charset below can eat its prefix as a literal
      if [[ "$line" =~ \$GROVE_SRC/[A-Za-z0-9._/-]*\$ ]]; then
        DYNAMIC+=( "${file#"$ROOT"/} — a runtime-built path" )
        continue
      fi
      # every `$GROVE_SRC/...` on the line, one per match
      while [[ "$line" =~ \$GROVE_SRC/([A-Za-z0-9._/-]+) ]]; do
        rest="${BASH_REMATCH[1]}"
        line="${line/\$GROVE_SRC\/${rest}/}"
        expanded="$(realpath -m --relative-to="$ROOT" "$ROOT/src/$rest" 2>/dev/null || true)"
        [[ -n "$expanded" ]] || continue
        LITERAL+=( "$expanded" )
      done
    done < <(sed 's/#.*$//' "$file" | grep -vE '^[[:space:]]*(echo|printf)[[:space:]]')
  done < <(find "$BUNDLES" -type f -name '*.sh' | sort)
}

collect

# de-duplicate: one asset is named by an upsert AND its verify, by design
mapfile -t ASSETS < <(printf '%s\n' "${LITERAL[@]}" | sort -u)

if [[ "${#ASSETS[@]}" -eq 0 ]]; then
  echo "✋ the bundle tree named 0 literal assets" >&2
  echo "   ⇒ a reader that matched none proves no claim about the set" >&2
  echo "   fix: confirm the tree is there — ls $BUNDLES" >&2
  exit 2
fi

######################################################################
# the census: the INDEX is asked about each, one at a time
######################################################################
count_untracked() {
  local a n=0
  for a in "${ASSETS[@]}"; do
    git -C "$ROOT" ls-files --error-unmatch "$a" >/dev/null 2>&1 || n=$(( n + 1 ))
  done
  echo "$n"
}

UNTRACKED=0
declare -a MISSING=()
for a in "${ASSETS[@]}"; do
  if git -C "$ROOT" ls-files --error-unmatch "$a" >/dev/null 2>&1; then
    echo "   ✔ $a"
  else
    MISSING+=( "$a" )
    UNTRACKED=$(( UNTRACKED + 1 ))
  fi
done
echo ""
echo "   ├─ assets named: ${#ASSETS[@]} (literal, de-duplicated)"
echo "   ├─ runtime-built: ${#DYNAMIC[@]} — out of this reader's reach, see below"
echo "   └─ untracked:    $UNTRACKED"
echo ""

# 🛑 the verdict cites THESE, taken BEFORE the bite plants its canary
#
# 📜 first cut: read `${#ASSETS[@]}` at the end, printed "all 19" against a census that had just said 18 — the array is RE-COLLECTED by the bite, so the verdict counted the planted world, not this tree (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.4)
ASSET_COUNT="${#ASSETS[@]}"
DYNAMIC_SEEN=( "${DYNAMIC[@]}" )

######################################################################
# 🛑 .THE BITE — a clamp never seen to fail is a guess
#   - `rule.require.clamp-edge-cases`: it must go RED on a real break and GREEN on a real pass
#   - a reference to an untracked asset is PLANTED, the count re-read, the plant removed
#
# ⚠️ the restore is a `trap … EXIT`, never a last line
#   - every step between the break and the repair can fail
#   - a failed step leaves the tree edited with no note of why (`rule.forbid.repair-plays`, exception 2, condition 1)
######################################################################
CANARY="$BUNDLES/1.system/1.4.sysctl/configure.verify.sh"
if [[ ! -f "$CANARY" ]]; then
  echo "🌙 the bite is SKIPPED — no canary file at ${CANARY#"$ROOT"/}" >&2
  echo "   ⇒ this play may only restore what it actually found, so it does not" >&2
  echo "     invent one (rule.forbid.repair-plays, exception 2, condition 2)" >&2
  echo "   ⚠️ the census above stands; the DISCRIMINATION does not" >&2
  exit 2
fi

BACKUP="$(mktemp "${TMPDIR:-/tmp}/asset.canary.XXXXXX")" || {
  echo "💥 could not open a scratch file — the canary was NOT touched" >&2
  exit 1
}
cp "$CANARY" "$BACKUP"
trap 'cp "$BACKUP" "$CANARY"; rm -f "$BACKUP"' EXIT

BEFORE="$UNTRACKED"

# the plant is MINIMAL: one line, one reference, at a path no tree holds
# ⇒ isolates the break to a single row instead of several unimplicated ones
printf '\nPLANTED_ASSET="$GROVE_SRC/no-such-asset-planted-by-a-probe.conf"\n' >> "$CANARY"

LITERAL=() DYNAMIC=()
collect
mapfile -t ASSETS < <(printf '%s\n' "${LITERAL[@]}" | sort -u)
AFTER="$(count_untracked)"

cp "$BACKUP" "$CANARY"
rm -f "$BACKUP"
trap - EXIT

echo "   ├─ bite: an untracked asset was planted in ${CANARY#"$ROOT"/}"
echo "   ├─ before: $BEFORE untracked"
echo "   ├─ after:  $AFTER untracked"

if cmp -s "$CANARY" <(git -C "$ROOT" show ":${CANARY#"$ROOT"/}" 2>/dev/null) \
   || git -C "$ROOT" diff --quiet -- "${CANARY#"$ROOT"/}"; then
  echo "   ├─ restore: ✔ ${CANARY#"$ROOT"/} matches its pre-probe copy"
else
  echo "   ├─ restore: ✋ ${CANARY#"$ROOT"/} DIFFERS from its pre-probe copy" >&2
  echo "   │  ⇒ read it before you trust this tree: git diff ${CANARY#"$ROOT"/}" >&2
  exit 1
fi

if [[ "$AFTER" -ne $(( BEFORE + 1 )) ]]; then
  echo "   └─ ✋ the reader did NOT bite — the plant moved the count $BEFORE → $AFTER" >&2
  echo "      ⇒ it cannot see an untracked asset, so its ✔ above proves no claim" >&2
  exit 1
fi
echo "   └─ 🌴 the reader BITES — the plant moved the count $BEFORE → $AFTER"
echo ""

######################################################################
# the verdict. the residue is printed BESIDE it, never folded into it
######################################################################
if [[ "${#DYNAMIC_SEEN[@]}" -gt 0 ]]; then
  echo "   ⚠️ ${#DYNAMIC_SEEN[@]} runtime-built reference(s) name no path a grep expands:"
  printf '      · %s\n' "${DYNAMIC_SEEN[@]}" | sort -u | head -8
  echo "      ⇒ they are neither passed nor failed below"
  echo ""
fi

if [[ "$UNTRACKED" -eq 0 ]]; then
  echo "🌲 assets: all $ASSET_COUNT literal asset(s) a bundle names are TRACKED ✔"
  exit 0
fi
echo "🌲 assets: $UNTRACKED of $ASSET_COUNT named asset(s) are NOT tracked" >&2
printf '   ✋ %s\n' "${MISSING[@]}" >&2
echo "   ⇒ each exists on this disk and ships to NOBODY. a fresh clone" >&2
echo "     converges a box that silently lacks it" >&2
echo "   fix: git add the path, then re-run" >&2
exit 1
